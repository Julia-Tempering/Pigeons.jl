@concrete struct StanLogPotential
    model
    initialization_std
end

stan_model(log_potential::StanLogPotential) = log_potential.model 
stan_model(log_potential::InterpolatedLogPotential) = log_potential.path.target.model

"""
Evaluate the log potential at a given point `x` of type `StanState`.
"""
(log_potential::StanLogPotential)(state::StanState) =
    LogDensityProblems.logdensity(log_potential, state.x)

LogDensityProblemsAD.ADgradient(::Symbol, log_potential::StanLogPotential, buffers::Augmentation) =
    BufferedAD(log_potential, buffers, Ref(0.0), Ref{Cstring}())

LogDensityProblems.logdensity(log_potential::BufferedAD{StanLogPotential{StanModel, Float64}}, x) =
    stan_log_density!(log_potential.enclosed.model, x, log_potential.logd_buffer, log_potential.err_buffer; propto = true, jacobian = true)

LogDensityProblems.logdensity(log_potential::StanLogPotential, x) =
    stan_log_density!(log_potential.model, x; propto = true, jacobian = true)


LogDensityProblems.dimension(log_potential::StanLogPotential) = convert(Int, BridgeStan.param_unc_num(log_potential.model))
function LogDensityProblems.logdensity_and_gradient(log_potential::BufferedAD{StanLogPotential{StanModel, Float64}}, x) 
    m = log_potential.enclosed.model
    b = log_potential.buffer
    # try
        return stan_log_density_gradient!(m, x, b, log_potential.logd_buffer, log_potential.err_buffer)
    # catch 
    #     # looks like NaN is giving "log_density_gradient() failed with unknown exception"
    #     # TODO: horrendeous... hopefully this can be improved (report to BridgeStan?)
    #     return -Inf, b 
    # end
end


"""
$SIGNATURES 
Given a `StanModel` from BridgeStan, create a 
`StanLogPotential` conforming to both [`target`](@ref) and [`log_potential`](@ref).
"""
@provides target StanLogPotential(model::BridgeStan.StanModel) = 
    StanLogPotential(model, 1e1) # TODO: find a good default

create_state_initializer(target::StanLogPotential, ::Inputs) = target  
function initialization(target::StanLogPotential, rng::SplittableRandom, _::Int64)
    d_unc = BridgeStan.param_unc_num(target.model) # number of unconstrained parameters 
    # init_unc = randn(rng, d_unc) * target.initialization_std
    # init = BridgeStan.param_constrain(target.model, init_unc)
    init = zeros(d_unc) # TODO: fix this, above crashes on some models
    return StanState(init, true)
end

create_explorer(::StanLogPotential, ::Inputs) = SliceSampler()

create_reference_log_potential(target::StanLogPotential, ::Inputs) = 
    StanLogPotential(target.model) # set reference = target for first few tuning rounds

function sample_iid!(log_potential::StanLogPotential, replica, shared) 
    # it doesn't seem possible to obtain iid samples from the prior with BridgeStan 
    # default to slicer as the explorer in the reference
    step!(shared.explorer, replica, shared)
end

# Allocation-free version of the BridgeStan functions.
# The rest of this file is a modification of BridgeStan's source

function stan_log_density!(sm::BridgeStan.StanModel, q::Vector{Float64}, lp = Ref(0.0), err = Ref{Cstring}(); propto = true, jacobian = true)
    rc = ccall(
        Libc.Libdl.dlsym(sm.lib, "bs_log_density"),
        Cint,
        (Ptr{BridgeStan.StanModelStruct}, Cint, Cint, Ref{Cdouble}, Ref{Cdouble}, Ref{Cstring}),
        sm.stanmodel,
        propto,
        jacobian,
        q,
        lp,
        err,
    )
    if rc != 0
        BridgeStan.error(BridgeStan.handle_error(sm.lib, err, "log_density"))
    end
    lp[]
end

function stan_log_density_gradient!(
    sm::BridgeStan.StanModel,
    q::Vector{Float64},
    out::Vector{Float64},
    lp, 
    err;
    propto = true,
    jacobian = true,
)
    dims = BridgeStan.param_unc_num(sm)
    if length(out) != dims
        throw(
            DimensionMismatch(
                "out must be same size as number of unconstrained parameters",
            ),
        )
    end
    rc = ccall(
        Libc.Libdl.dlsym(sm.lib, "bs_log_density_gradient"),
        Cint,
        (
            Ptr{BridgeStan.StanModelStruct},
            Cint,
            Cint,
            Ref{Cdouble},
            Ref{Cdouble},
            Ref{Cdouble},
            Ref{Cstring},
        ),
        sm.stanmodel,
        propto,
        jacobian,
        q,
        lp,
        out,
        err,
    )
    if rc != 0
        error(handle_error(sm.lib, err, "log_density_gradient"))
    end
    (lp[], out)
end