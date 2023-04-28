"""
A [`Base.@kwdef`](https://github.com/JuliaLang/julia/blob/79ceb8dbeab1b5a47c6bd664214616c19607ffab/base/util.jl#L514) struct 
used to create Parallel Tempering algorithms. 


Fields (see source file for default values):
$FIELDS
"""
@kwdef mutable struct Inputs{I, V}
    """ The target distribution. """
    target::I

    """ The master random seed. """
    seed::Int = 1

    """ The number of rounds to run. """
    n_rounds::Int = 10

    """ The number of chains to use for the fixed reference leg. """
    n_chains::Int = 10

    """ The number of chains to use for the variational reference leg. """
    n_chains_var_reference::Int = 0
    
    """ The variational reference family. """
    var_reference::V = NoVarReference()

    """ 
    Whether a checkpoint should be written to disk 
    at the end of each round. 
    """
    checkpoint::Bool = false

    """
    An Vector with elements of type 
    [`recorder_builder`](@ref). 
    """
    recorder_builders::Vector = default_recorder_builders()

    """
    The round index where [`run_checks()`](@ref) will 
    be performed. Set to 0 to skip these checks. 
    """
    checked_round::Int = 0

    """
    If multithreaded explorers should be allowed. 
    False by default since it incurs an overhead. 
    """
    multithreaded::Bool = false

    function Inputs(target::I, seed, n_rounds, n_chains, n_chains_var_reference,
                    var_reference::V, checkpoint, recorder_builders, checked_round, multithreaded) where {I, V}
        @assert (n_chains ≥ 0) & (n_chains_var_reference ≥ 0) & (n_chains + n_chains_var_reference ≥ 2)
        if (n_chains_var_reference == 0)
            @assert isa(var_reference, NoVarReference)
        end
        return new{I,V}(
            target, seed, n_rounds, n_chains, n_chains_var_reference,
            var_reference, checkpoint, recorder_builders, checked_round, multithreaded
        )
    end
end


"""
Set of recorders with no measurable impact on performance. 
"""
default_recorder_builders() = [
    log_sum_ratio,
    timing_extrema, 
    allocation_extrema
]

"""
Set of constant memory recorders.
"""
online_recorder_builders() = [
    log_sum_ratio,
    timing_extrema, 
    allocation_extrema,
    round_trip,
    energy_ac1, 
    target_online
]

"""
Extract the number of Parallel Tempering chains from `Inputs`.
"""
number_of_chains(inputs::Inputs) = number_of_chains_fixed(inputs) + number_of_chains_var(inputs)
# TODO: generalize once you have "parallel parallel tempering", etc.
number_of_chains_fixed(inputs::Inputs) = inputs.n_chains
number_of_chains_var(inputs::Inputs) = inputs.n_chains_var_reference