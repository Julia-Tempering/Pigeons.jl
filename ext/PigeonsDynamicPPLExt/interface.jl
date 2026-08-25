"""
$SIGNATURES

Convenience constructor for [`Pigeons.TuringLogPotential`](@ref).
"""

function Pigeons.TuringLogPotential(model::DynamicPPL.Model, only_prior::Bool)
    getlogdensity = only_prior ? DynamicPPL.getlogprior_internal : DynamicPPL.getlogjoint_internal

    # workaround to avoid touching global rng
    tmp_rng = Xoshiro(468)
    accs = OnlyAccsVarInfo(VectorValueAccumulator())
    _, accs = init!!(tmp_rng, model, accs, InitFromPrior(), LinkAll())
    ldf = LogDensityFunction(model, getlogdensity, accs)

    return TuringLogPotential(model, ldf, LogDensityProblems.dimension(ldf))
end

function (log_potential::Pigeons.TuringLogPotential)(vi)
    try
        LogDensityProblems.logdensity(log_potential.ldf, vi[:])
    catch e
        (isa(e, DomainError) || isa(e, BoundsError)) && return -Inf
        rethrow(e)
    end
end

"""
$SIGNATURES
Given a `DynamicPPL.Model` from Turing.jl, create a
`TuringLogPotential` conforming both [`target`](@ref) and
[`log_potential`](@ref).
"""
Pigeons.@provides target Pigeons.TuringLogPotential(model::DynamicPPL.Model) =
    TuringLogPotential(model, false)

is_fully_continuous(vi::DynamicPPL.VarInfo) =
    all(tv -> eltype(DynamicPPL.get_internal_value(tv)) <: AbstractFloat, values(vi))

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
    vi = DynamicPPL.VarInfo(rng, target.model, DynamicPPL.InitFromPrior())
    vi = DynamicPPL.link(vi, target.model)
    # DynamicPPL.unflatten!! will force all variables(dis/cts) into Float!
    return vi
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
        log_potential.model, DynamicPPL.getlogjoint_internal, replica.state; adtype=kind
    )
    d = LogDensityProblems.dimension(log_potential)
    buffer = Pigeons.get_buffer(replica.recorders.buffers, :gradient_buffer, d)
    return Pigeons.BufferedAD(ldf, buffer, nothing, nothing)
end


# adapted from DPPL to use buffer 
# https://github.com/TuringLang/DynamicPPL.jl/blob/fb5413f482b962d97b6e4728d560297cd713c295/src/logdensityfunction.jl#L202

function LogDensityProblems.logdensity_and_gradient(
    b::Pigeons.BufferedAD{<:DynamicPPL.LogDensityFunction},
    params::AbstractVector
    )
    ldf = b.enclosed
    buffer = b.buffer

    @static if pkgversion(DynamicPPL) < v"0.42"
        ldf._adprep === nothing &&
            error("Gradient preparation not available; this should not happen")
        params = convert(DynamicPPL.get_input_vector_type(ldf), params)  # Concretise type
        # Make branching statically inferrable, i.e. type-stable (even if the two
        # branches happen to return different types)
        return if DynamicPPL._use_closure(ldf.adtype)
            DI.value_and_gradient!(
                DynamicPPL.LogDensityAt(
                    ldf.model,
                    ldf._getlogdensity,
                    ldf._varname_ranges,
                    ldf.transform_strategy,
                    ldf._accs,
                ),
                buffer,
                ldf._adprep,
                ldf.adtype,
                params,
            )
        else
            DI.value_and_gradient!(
                DynamicPPL.logdensity_at,
                buffer,
                ldf._adprep,
                ldf.adtype,
                params,
                DI.Constant(ldf.model),
                DI.Constant(ldf._getlogdensity),
                DI.Constant(ldf._varname_ranges),
                DI.Constant(ldf.transform_strategy),
                DI.Constant(ldf._accs),
            )
        end
    else
        error("Doesn't work with DPPL@0.42 yet")
    end
end

