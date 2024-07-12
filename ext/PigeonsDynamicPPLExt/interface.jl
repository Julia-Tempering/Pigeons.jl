"""
$SIGNATURES

Convenience constructor for [`Pigeons.TuringLogPotential`](@ref).
"""
Pigeons.TuringLogPotential(model::DynamicPPL.Model, only_prior::Bool) = 
    TuringLogPotential(
        model, 
        only_prior ? DynamicPPL.PriorContext() : DynamicPPL.DefaultContext(),
        get_dimension(model)
    )


(log_potential::Pigeons.TuringLogPotential{<:Any,<:DynamicPPL.DefaultContext})(vi) =
    try
        DynamicPPL.logjoint(log_potential.model, vi)
    catch e
        (isa(e, DomainError) || isa(e, BoundsError)) && return -Inf
        rethrow(e)
    end

(log_potential::Pigeons.TuringLogPotential{<:Any,<:DynamicPPL.PriorContext})(vi) =
    try
        DynamicPPL.logprior(log_potential.model, vi)
    catch e
        (isa(e, DomainError) || isa(e, BoundsError)) && return -Inf
        rethrow(e)
    end

"""
$SIGNATURES
Given a `DynamicPPL.Model` from Turing.jl, create a
`TuringLogPotential` conforming both [`target`](@ref) and
[`log_potential`](@ref).
"""
Pigeons.@provides target Pigeons.TuringLogPotential(model::DynamicPPL.Model) =
    TuringLogPotential(model, false)

is_fully_continuous(vi::DynamicPPL.TypedVarInfo) =
    all(meta -> eltype(meta.vals) <: AbstractFloat, vi.metadata)

# checks needed when using gradient-based explorers
function Pigeons.initialization(
    inp::Inputs{<:Pigeons.TuringLogPotential, <:Any, <:Pigeons.GradientBasedSampler}, 
    args...
    )
    vi = Pigeons.initialization(inp.target, args...)
    is_fully_continuous(vi) || throw(ArgumentError("""

        An explorer of type $(typeof(inp.explorer)) cannot be directly used with
        DynamicPPL models describing discrete variables. Use SliceSampler instead,
        for example.

    """))

    @warn   """
    
            We recommend using SliceSampler() for Turing models. If you have a large continuous model
            consider using the BridgeStan (which has much faster autodiff than Zygote, and Enzyme 
            crashes on Turing at the time of writing). The Turing interface is still useful for models
            containing both continuous and discrete variables.
            """ maxlog=1

    return vi
end

# Catch using TuringLogPotential with GradientBasedSampler and 
# GaussianReference (not yet supported)
Pigeons.initialization(
    ::Inputs{<:Pigeons.TuringLogPotential, <:Pigeons.GaussianReference, <:Pigeons.GradientBasedSampler},
    args...) = error("""
    
    Using a TuringLogPotential with a gradient-based sampler and Gaussian 
    variational reference is not yet supported. You can use a non-gradient 
    explorer like SliceSampler.
    """)

function Pigeons.initialization(target::TuringLogPotential, rng::AbstractRNG, _::Int64)
    result = DynamicPPL.VarInfo(rng, target.model, DynamicPPL.SampleFromPrior(), DynamicPPL.PriorContext())
    DynamicPPL.link!!(result, DynamicPPL.SampleFromPrior(), target.model)
    return result
end

# At the moment, AutoMALA assumes a :singleton_variable structure
# so use the SliceSampler.
Pigeons.default_explorer(::TuringLogPotential) = SliceSampler()

Pigeons.default_reference(target::TuringLogPotential) =
    TuringLogPotential(target.model, true)

function Pigeons.sample_iid!(log_potential::TuringLogPotential, replica, shared)
    replica.state = Pigeons.initialization(log_potential, replica.rng, replica.replica_index)
end

# LogDensityProblems interface
LogDensityProblems.dimension(log_potential::TuringLogPotential) = log_potential.dimension

# ADgradient
# general case
LogDensityProblemsAD.ADgradient(kind::Val, log_potential::TuringLogPotential, replica::Pigeons.Replica) =
    ADgradient(
        kind, 
        DynamicPPL.LogDensityFunction(replica.state, log_potential.model, log_potential.context), 
        replica)

# ForwardDiff can create a GradientConfig based on the dimensions and 
# element type of the input. We use a FillArray to avoid an allocation
function LogDensityProblemsAD.ADgradient(
    kind::Val{:ForwardDiff},
    log_potential::TuringLogPotential,
    replica::Pigeons.Replica
    )
    vi = replica.state
    fct = DynamicPPL.LogDensityFunction(vi, log_potential.model, log_potential.context)
    x_template = Zeros{typeof(DynamicPPL.getlogp(vi))}(log_potential.dimension)
    return ADgradient(kind, fct, replica; x=x_template)
end
