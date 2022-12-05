"""
Assume all the MPI processes linked by this communicator 
will all call the transmit() method the same number of times 
in their lifetime, at logically related occasions (e.g. a set 
number of times per iterations for algorithms running the 
same number of iterations).
We call these 'occasions' a micro-iteration.
"""
mutable struct Entangler
    communicator::Union{Comm,Nothing}
    load::LoadBalance
    current_received_bits::Vector{Bool}
    n_transmits::Int
    """
    If parent_communicator is nothing, then assume there is only 
    one machine (self) and bypass MPI.
    """
    function Entangler(n_global_indices::Int; parent_communicator::Union{Comm,Nothing} = COMM_WORLD, verbose::Bool=true)
        if parent_communicator === nothing
            # do everything locally (no network comm)
            comm = nothing
            my_process_index = 1
            n_processes = 1
            if verbose
                println("Entangler initialized 1 process (without MPI)")
            end
        else
            Init() # MPI.Init()
            comm = Comm_dup(parent_communicator)
            my_process_index = Comm_rank(comm) + 1
            n_processes = Comm_size(comm)
            if verbose && my_process_index == 1
                println("Entangler initialized $n_processes MPI processes")
            end
        end
  
        lb = LoadBalance(my_process_index, n_processes, n_global_indices)
        received_bits = Vector{Bool}(undef, my_load(lb))
        return new(comm, lb, received_bits, 0)
    end
end

"""
For each i, source_data[i] is sent to_global_indices[i].
Returns the data received for each e's load balancer's global index 
(see LoadBalance for functions mapping the 'local index' i to a global index and back).

See Entangler's comments regarding the requirement that all machines call transmit() the 
same number of times and at logically related intervals. 

Additionally, at each micro-iteration, we assume that 
{to_global_indices_p : p ranges over the difference processes} forms a partition of 
{1, ..., e.load.n_global_indices}
    (if ran in single-process mode, this 'partition property' will be checked [TODO: write test]
     if ran in multi-process, opportunistic checks will be made [when several entries in to_global_indices 
     lie in the same process] but systematic checks are not made for performance reasons])
"""
function transmit(e::Entangler, source_data::AbstractVector{T}, to_global_indices::AbstractVector{Int})::Vector{T} where T
    result = Vector{T}(undef, length(source_data))  
    transmit!(e, source_data, to_global_indices, result)
    return result
end

function tag(e::Entangler, transmit_index::Int, global_index::Int)
    return transmit_index * e.load.n_global_indices + global_index
end

function transmit!(e::Entangler, source_data::AbstractVector{T}, to_global_indices::AbstractVector{Int}, write_received_data_here::Vector{T}) where T 
    myload = my_load(e.load)
    @assert myload == length(source_data) == length(write_received_data_here) == length(to_global_indices)
    @assert all(1 .≤ to_global_indices .≤ e.load.n_global_indices)
    transmit_index = next_transmit_index!(e)

    # indicators of whether each local index is to be received over MPI
    e.current_received_bits .= true 
    at_least_one_mpi = false
    
    # send (or copy if local)
    for local_index in 1:myload
        global_index = to_global_indices[local_index]
        process_index = find_process(e.load, global_index)
        source_datum = source_data[local_index]
        
        if process_index == e.load.my_process_index
            dest_local_index = find_local_index(e.load, global_index)
            @assert e.current_received_bits[dest_local_index] "Violation of permutation property detected: two transmissions to $global_index"
            e.current_received_bits[dest_local_index] = false
            write_received_data_here[dest_local_index] = source_datum
        else
            at_least_one_mpi = true
            source_view = Ref{T}(source_datum)
            mpi_rank = process_index - 1
            # asynchronously (non-blocking) send over MPI:
            Isend(source_view, e.communicator, dest = mpi_rank, tag = tag(e, transmit_index, global_index))
        end
    end

    # receive
    if at_least_one_mpi
        requests = RequestSet()
        my_globals = my_global_indices(e.load)
        for local_index in 1:myload
            if e.current_received_bits[local_index]
                dest_view = @view write_received_data_here[local_index]
                global_index = my_globals[local_index]
                # asynchronously receive over MPI (non-blocking)
                request = Irecv!(dest_view, e.communicator, tag = tag(e, transmit_index, global_index))
                push!(requests, request)
            end
        end

        # wait that all data is received
        Waitall(requests)
    end
end

function next_transmit_index!(e::Entangler)::Int
    result = e.n_transmits
    e.n_transmits += 1
    return result
end

function reduce_deterministically(operation, source_data::AbstractVector{T}, e::Entangler) where T
    myload = my_load(e.load)
    @assert length(source_data) == myload
    n_remaining_to_reduce = e.load.n_global_indices
    # merging will be done in this array
    work_array = copy(source_data)
    spacing = 1 # as we reduce, the spacing between remaining entries will double every iteration
    # 'global' refers to the index space shared by all machines, 'local' to the index this machines sees (indexing source_data and work_array)
    myglobals = my_global_indices(e.load)
    n_global_indices_remaining_before = first(myglobals) - 1
    # as we send off entries to the left neighbour machine, this process' first entry will shift
    my_first_remaining_local = 1
    # outer loop is over the levels of a binary tree over the global indices
    iteration = 1
    while n_remaining_to_reduce > 1
        transmit_index = next_transmit_index!(e)
        current_local = my_first_remaining_local
        # on the current level of the tree, merge neighbour indices
        did_send = false
        while current_local ≤ myload 
            current_global = first(myglobals) + current_local - 1
            if isodd(n_global_indices_remaining_before) && current_local == my_first_remaining_local
                # need to send the first off to left neighbour
                dest_global_index = current_global - spacing 
                dest_process = find_process(e.load, dest_global_index)
                dest_rank = dest_process - 1
                isend(work_array[current_local], e.communicator; dest = dest_rank, tag = tag(e, transmit_index, iteration))
                current_local += spacing           
                did_send = true     
            elseif current_global + spacing ≤ e.load.n_global_indices
                
                # a merge into work_array[current_local]
                first_to_merge = work_array[current_local]
                # second could be local or a receive
                second_local_index = current_local + spacing 

                second_to_merge = second_local_index ≤ myload ?                    # second entry from...
                    work_array[second_local_index] :                               # ...another entry in this machine, or,
                    recv(e.communicator; tag = tag(e, transmit_index, iteration) ) # ...neighbour machine
                
                # merge
                work_array[current_local] = operation(first_to_merge, second_to_merge)
                current_local += 2*spacing
            else
                # the last entry of the last machine may not merge when the current level has 
                # an odd number of entries. It will be taken care of in the next level
                current_local += 2*spacing
            end  
        end
        if did_send 
            my_first_remaining_local += spacing
        end
        n_global_indices_remaining_before = ceil(Int, n_global_indices_remaining_before/2)
        spacing = spacing * 2
        n_remaining_to_reduce = ceil(Int, n_remaining_to_reduce/2)
        iteration += 1
    end
    return e.load.my_process_index == 1 ? work_array[1] : nothing
end

function all_reduce_deterministically(operation, source_data::AbstractVector{T}, e::Entangler) where T
    if e.load.my_process_index == 1
        result = reduce_deterministically(operation, source_data, e)
        if e.load.n_processes > 1
            bcast(result, e.communicator)
        end
        return result
    else
        reduce_deterministically(operation, source_data, e)
        return bcast(nothing, e.communicator)
    end
end
