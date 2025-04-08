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
    vi = DynamicPPL.VarInfo(rng, target.model, DynamicPPL.SampleFromPrior(), DynamicPPL.PriorContext())
    return DynamicPPL.link(vi, target.model)
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

function LogDensityProblemsAD.ADgradient(
    kind::ADTypes.AbstractADType, 
    log_potential::TuringLogPotential, 
    replica::Pigeons.Replica
    )
    ldf = DynamicPPL.LogDensityFunction(
        log_potential.model, replica.state; adtype=kind
    )
    d = LogDensityProblems.dimension(log_potential)
    buffer = Pigeons.get_buffer(replica.recorders.buffers, :gradient_buffer, d)
    return Pigeons.BufferedAD(ldf, buffer, nothing, nothing)
end

# adapted from DPPL to use buffer 
# https://github.com/TuringLang/DynamicPPL.jl/blob/fb5413f482b962d97b6e4728d560297cd713c295/src/logdensityfunction.jl#L202
function LogDensityProblems.logdensity_and_gradient(
    b::Pigeons.BufferedAD{<:DynamicPPL.LogDensityFunction},
    x::AbstractVector
    )
    f = b.enclosed
    buffer = b.buffer

    f.prep === nothing &&
        error("Gradient preparation not available; this should not happen")
    x = map(identity, x)  # Concretise type
    # Make branching statically inferrable, i.e. type-stable (even if the two
    # branches happen to return different types)
    return if DynamicPPL.use_closure(f.adtype)
        DI.value_and_gradient!(
            x -> DynamicPPL.logdensity_at(x, f.model, f.varinfo, f.context),
            buffer,
            f.prep, 
            f.adtype, 
            x
        )
    else
        DI.value_and_gradient!(
            DynamicPPL.logdensity_at,
            buffer,
            f.prep,
            f.adtype,
            x,
            DI.Constant(f.model),
            DI.Constant(f.varinfo),
            DI.Constant(f.context),
        )
    end
end

