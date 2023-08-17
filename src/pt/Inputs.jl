"""
A [`Base.@kwdef`](https://github.com/JuliaLang/julia/blob/79ceb8dbeab1b5a47c6bd664214616c19607ffab/base/util.jl#L514) struct 
used to create Parallel Tempering algorithms. 


Fields (see source file for default values):
$FIELDS
"""
@kwdef mutable struct Inputs{T, V, E, R}
    """ The target distribution. """
    target::T

    """ The master random seed. """
    seed::Int = 1

    """ The number of rounds to run. """
    n_rounds::Int = 10

    """ The number of chains to use (but see also `n_chains_variational`). """
    n_chains::Int = 10

    """ 
    The number of chains to use for an additional variational reference leg. 
    Set to zero to disable (default). 
    Variational inference can also be performed using a single leg, however 
    the two-leg version is more stable: see https://arxiv.org/abs/2206.00080
    """
    n_chains_variational::Int = 0

    """ The reference distribution (e.g. a prior), or if nothing and a 
    fixed reference is needed (i.e. variational inference is disabled or 
    two-legged variational inference is used), then
    [`default_reference()`](@ref) will be called to 
    automatically determine the reference based on the 
    type of the target.  """
    reference::R = nothing
    
    """ The variational reference family, or nothing to disable 
    variational inference. """
    variational::V = nothing

    """ 
    Whether a checkpoint should be written to disk 
    at the end of each round. 
    """
    checkpoint::Bool = false

    """
    Determine what should be stored from the simulation.
    A Vector with elements of type 
    [`recorder_builder`](@ref). 
    """
    record::Vector = record_default()

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

    """ 
    The [`explorer`](@ref) to use, or if nothing, 
    will use [`default_explorer()`](@ref) to 
    automatically determine the explorer based on the 
    type of the target. 
    """
    explorer::E = nothing

    """
    Show sampling report?
    """
    show_report::Bool = true

    """
    Type of traces to collect:

    - `:samples` - `extract_sample()` is called on the state, or
    - `:log_potential` - `log_potential()` is called on the state
    """
    trace_type::Symbol = :samples
end

"""
Set of recorders with no measurable impact on performance. 
"""
record_default() = [
    log_sum_ratio,
    timing_extrema, 
    allocation_extrema
]

"""
Set of constant memory recorders.
"""
record_online() = [
    log_sum_ratio,
    timing_extrema, 
    allocation_extrema,
    round_trip,
    energy_ac1, 
    online
]

"""
Extract the number of Parallel Tempering chains from `Inputs`.
"""
n_chains(inputs::Inputs) = n_chains_fixed(inputs) + n_chains_var(inputs)
# TODO: generalize once you have "parallel parallel tempering", etc.
n_chains_fixed(inputs::Inputs) = inputs.n_chains
n_chains_var(inputs::Inputs) = inputs.n_chains_variational