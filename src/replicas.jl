"""
Stores the process' replicas. 
Since we provide MPI implementations, do not assume that this will contain all the replicas, as 
others can be located in other processes/machines

Implementations provided
    - [`EntangledReplicas`](@ref): using an MPI-based implementation
    - `Vector{Replica}`: for the single process case (above can handle that case, but the array based implementation is non-allocating)
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
    Return the [`LoadBalance`](@ref) (possibly [`single_process_load`](@ref))
    """
    load(replicas) = @abstract
    """
    $TYPEDSIGNATURES
    Return the `MPI.Comm` or `nothing` if no MPI needed
    """
    communicator(replicas) = @abstract 
    """
    $TYPEDSIGNATURES
    Return the [`Entangler`](@ref) (possibly a no-communication Entangler)
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
    Determine [`state_initializer`](@ref)'s initialization for the given `chain`.
    """
    initialization(state_initializer, rng::SplittableRandom, chain::Int) = @abstract
end
# ... initialize all to the same state
initialization(state_initializer::Ref, rng::SplittableRandom, chain::Int) = state_initializer[]
# ... initialize to a value specific to each chain
initialization(state_initializer::AbstractVector, rng::SplittableRandom, chain::Int) = state_initializer[chain]
# ... TODO: initialize from prior / other smart inits


"""
$TYPEDSIGNATURES
Create [`replicas`](@ref) when distributed computing is not needed. 
See also [`state_initializer`](@ref).
"""
@provides replicas function create_vector_replicas(
        n_chains::Int, 
        state_initializer, 
        rng::SplittableRandom,
        recorder_keys::Set{Symbol} = Set{Symbol}())
    split_rngs = split_slice(1:n_chains, rng)
    states = [initialization(state_initializer, split_rngs[i], i) for i in eachindex(split_rngs)]
    recorders = [custom_recorders(recorder_keys) for i in eachindex(split_rngs)]
    return Replica.(states, 1:n_chains, split_rngs, recorders, 1:n_chains)
end