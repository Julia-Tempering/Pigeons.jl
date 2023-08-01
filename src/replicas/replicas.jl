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
    $(SIGNATURES)
    For each pair of chains encoded in [`swap_graph`](@ref), use 
    [`pair_swapper`](@ref) to decide if the pair will swap or not, 
    and write the changes in-place into [`replicas`](@ref) (i.e. exchanging 
    the `Replica`'s `chain` fields for those that swapped.)
    """
    swap!(pair_swapper, replicas, swap_graph) = @abstract 
    """
    $(SIGNATURES)
    Return the replica's that are stored in this machine
    """
    locals(replicas) = @abstract 
    """
    $SIGNATURES
    Return the [`replicas`](@ref)'s [`LoadBalance`](@ref) (possibly [`single_process_load`](@ref))
    """
    load(replicas) = @abstract
    """
    $SIGNATURES
    Return the [`replicas`](@ref)'s `MPI.Comm` or `nothing` if no MPI needed
    """
    communicator(replicas) = @abstract 
    """
    $SIGNATURES
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
Flag [`create_replicas`](@ref) (and related functions) that replicas 
should be loaded from a checkpoint. Fields:
$FIELDS
"""
struct FromCheckpoint 
    checkpoint_folder::String 
end

"""
$SIGNATURES
Create [`replicas`](@ref), detecting automatically if MPI is needed. 

Argument `source` is either nothing, when creating new states, 
or [`FromCheckpoint`](@ref) to load from 
a saved checkpoint.
"""
@provides replicas create_replicas(inputs::Inputs, shared::Shared, source = nothing) = 
    mpi_active() ? 
        create_entangled_replicas(inputs, shared, source) :
        create_vector_replicas(inputs, shared, source)

"""
$SIGNATURES
Create [`replicas`](@ref) when distributed computing is not needed. 

See [`create_replicas`](@ref).
"""
@provides replicas function create_vector_replicas(inputs::Inputs, shared::Shared, source)
    my_global_indices = 1:n_chains(inputs)
    result = _create_locals(my_global_indices, inputs, shared, source)
    sort_replicas!(result) # <- needed when deserializing
    return result
end

function _create_locals(my_global_indices, ::Inputs, ::Shared, source::FromCheckpoint)
    return [deserialize("$(source.checkpoint_folder)/replica=$global_index.jls") for global_index in my_global_indices]
end

function _create_locals(my_global_indices, inputs::Inputs, shared::Shared, ::Nothing)
    master_rng = SplittableRandom(inputs.seed)
    split_rngs = split_slice(my_global_indices, master_rng)
    states = [initialization(inputs, split_rngs[i], my_global_indices[i]) for i in eachindex(split_rngs)]
    recorders = [create_recorders(inputs, shared) for i in eachindex(split_rngs)]
    return Replica.(
                states, 
                my_global_indices,  # <- chain indices initialized to replica indices
                split_rngs,
                recorders, 
                my_global_indices)  # <- replica indices
end

# default method: defer to user-provided method for their target
initialization(inp::Inputs, args...) = initialization(inp.target, args...)

# generic method for distribution-type references: sample iid for all replicas
function initialization(
    inp::Inputs{T, V, E, R},
    rng::AbstractRNG,
    ::Int
    ) where {T, V, E, R <: DistributionLogPotential}
    rand(rng, inp.reference.dist)
end

# for univariate references we need to wrap in vector 
function initialization(
    inp::Inputs{T, V, E, R},
    rng::AbstractRNG,
    ::Int
    ) where {T, V, E, R <: DistributionLogPotential{<:UnivariateDistribution}}
    [rand(rng, inp.reference.dist)]
end

