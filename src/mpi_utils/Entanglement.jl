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

function transmit!(e::Entangler, source_data::AbstractVector{T}, to_global_indices::AbstractVector{Int}, write_received_data_here::Vector{T}) where T 
    myload = my_load(e.load)
    @assert myload == length(source_data) == length(write_received_data_here) == length(to_global_indices)
    @assert all(1 .≤ to_global_indices .≤ e.load.n_global_indices)
    tag_offset = next_transmit_index!(e) * e.load.n_global_indices
    
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
            Isend(source_view, e.communicator, dest = mpi_rank, tag = global_index + tag_offset)
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
                request = Irecv!(dest_view, e.communicator, tag = global_index + tag_offset)
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
