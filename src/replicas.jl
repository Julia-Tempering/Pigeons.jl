"""
Stores the process' replicas. 
Since we provide MPI implementations, do not assume that this will contain all the replicas, as 
others can be located in other processes/machines

Implementations provided

- [`EntangledReplicas`](@ref): an MPI-based implementation
- `Vector{Replica}`: single-process case (above can handle that case, but the array based implementation is non-allocating)
"""
@informal replicas begin
    """
    $(TYPEDSIGNATURES)
    For each pair of chains encoded in [`swap_graph`](@ref), use 
    [`pair_swapper`](@ref) to decide if the pair will swap or not, 
    and write the changes in-place into [`replicas`](@ref) (i.e. exchanging 
    the `Replica`'s `chain` fields for those that swapped.)
    """
    swap!(pair_swapper, replicas, swap_graph) = @abstract 
    """
    $(TYPEDSIGNATURES)
    Return the replica's that are stored in this machine
    """
    locals(replicas) = @abstract 
    """
    $TYPEDSIGNATURES
    Return the [`replicas`](@ref)'s [`LoadBalance`](@ref) (possibly [`single_process_load`](@ref))
    """
    load(replicas) = @abstract
    """
    $TYPEDSIGNATURES
    Return the [`replicas`](@ref)'s `MPI.Comm` or `nothing` if no MPI needed
    """
    communicator(replicas) = @abstract 
    """
    $TYPEDSIGNATURES
    Return the [`replicas`](@ref)'s [`Entangler`](@ref) (possibly a no-communication Entangler if a single process is involved)
    """
    entangler(replicas) = @abstract 
end

# Non-distributed implementation allowing zero-allocation swaps:
locals(replicas::Vector) = replicas
load(replicas::Vector) = single_process_load(length(replicas))
communicator(replicas::Vector) = nothing
entangler(replicas::Vector) = Entangler(length(replicas); parent_communicator = nothing, verbose = false)

"""
$TYPEDSIGNATURES
Given a [`replicas`](@ref), return the total number of chains across all processes.
"""
n_chains_global(replicas) = load(replicas).n_global_indices


"""
Determine how to initialize the states in the replicas. 
Implementations include `Ref(my_state)`, to signal all replicas will 
be initalized to `my_state`, or a `Vector(...)` for chain-specific 
initializations. 
"""
@informal state_initializer begin 
    """
    $TYPEDSIGNATURES
    Determine [`state_initializer`](@ref)'s initialization for the given `replica_index`.
    """
    initialization(state_initializer, rng::SplittableRandom, replica_index::Int) = @abstract
end
# ... initialize all to the same state
initialization(state_initializer::Ref, ::SplittableRandom, ::Int) = state_initializer[]
# ... initialize to a value specific to each chain
initialization(state_initializer::AbstractVector, ::SplittableRandom, replica_index::Int) = state_initializer[replica_index]
# ... TODO: initialize from prior / other smarter inits

"""
$TYPEDSIGNATURES
Create [`replicas`](@ref) when distributed computing is not needed. 
See also [`state_initializer`](@ref).
"""
@provides replicas function create_vector_replicas(shared::Shared, round_folder = nothing)
    my_global_indices = 1:shared.n_chains
    return _create_locals(my_global_indices, shared, round_folder)
end

@provides replicas create_replicas(shared::Shared, round_folder = nothing) = 
    mpi_needed() ? 
        create_entangled_replicas(shared, round_folder) :
        create_vector_replicas(shared, round_folder)

function _create_locals(my_global_indices, shared::Shared, round_folder::String)
    locals = [deserialize(round_folder / "checkpoint/replica=$global_index.jls") for global_index in my_global_indices]
    # we rely on having only one instance of the shared object, 
    # so that iteration increments can be detected by recorders; 
    # so we do a small surgery:
    for replica in locals
        replica.recorders = Recorders(replica.recorders.contents, shared)
    end
    return locals 
end

function _create_locals(my_global_indices, shared::Shared, ::Nothing)
    split_rngs = split_slice(my_global_indices, shared.inputs.rng)
    states = [initialization(shared.state_initializer, split_rngs[i], my_globals_indices[i]) for i in eachindex(split_rngs)]
    recorders = [Recorders(shared.recorder_builders, shared) for i in eachindex(split_rngs)]
    return Replicas.(
                states, 
                my_global_indices,  # <- chain indices initialized to replica indices
                recorders, 
                my_global_indices)  # <- replica indices
end
