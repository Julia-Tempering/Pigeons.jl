@auto struct StanLogPotential
    model
    # keep those to be able to serialize/deserialize 
    stan_file 
    data 
end
StanLogPotential(stan_file, data) = 
    StanLogPotential(
        BridgeStan.StanModel(; stan_file, data), 
        stan_file, 
        Immutable(data)
    )
function Serialization.serialize(s::AbstractSerializer, instance::StanLogPotential{M, S, D}) where {M, S, D}
    Serialization.writetag(s.io, Serialization.OBJECT_TAG)
    Serialization.serialize(s, StanLogPotential{M, S, D})
    # do not serialize model as it is transient (ccall stuff)
    Serialization.serialize(s, instance.stan_file)
    Serialization.serialize(s, instance.data)
end

function Serialization.deserialize(s::AbstractSerializer, type::Type{StanLogPotential{M, S, D}}) where {M, S, D}
    stan_file = Serialization.deserialize(s)
    immutable = Serialization.deserialize(s)
    return StanLogPotential(stan_file, immutable.data)
end
Base.show(io::IO, slp::StanLogPotential) = 
    print(io, "StanLogPotential($(name(slp.model)))")

stan_model(log_potential::StanLogPotential) = log_potential.model 
stan_model(log_potential::InterpolatedLogPotential) = log_potential.path.target.model

default_explorer(::StanLogPotential) = AutoMALA()

"""
Evaluate the log potential at a given point `x` of type `StanState`.
"""
(log_potential::StanLogPotential)(state::StanState) =
    LogDensityProblems.logdensity(log_potential, state.x)

LogDensityProblemsAD.ADgradient(::Symbol, log_potential::StanLogPotential, buffers::Augmentation) =
    BufferedAD(log_potential, buffers, Ref(0.0), Ref{Cstring}())

LogDensityProblems.logdensity(log_potential::BufferedAD{StanLogPotential{M, S, D}}, x) where {M, S, D} =
    stan_log_density!(
        log_potential.enclosed.model, x, log_potential.logd_buffer, log_potential.err_buffer; 
        propto = false) # note: propto = false to get correct log normalization constants

LogDensityProblems.logdensity(log_potential::StanLogPotential, x) =
    stan_log_density!(log_potential.model, x; 
        propto = false) # note: propto = false to get correct log normalization constants


LogDensityProblems.dimension(log_potential::StanLogPotential) = convert(Int, BridgeStan.param_unc_num(log_potential.model))
function LogDensityProblems.logdensity_and_gradient(log_potential::BufferedAD{StanLogPotential{M, S, D}}, x) where {M, S, D}
    m = log_potential.enclosed.model
    b = log_potential.buffer
    return stan_log_density_gradient!(m, x, b, log_potential.logd_buffer, log_potential.err_buffer;
        propto = false) # note: propto = false to get correct log normalization constants
end

create_state_initializer(target::StanLogPotential, ::Inputs) = target  
function initialization(target::StanLogPotential, rng::SplittableRandom, _::Int64)
    d_unc = BridgeStan.param_unc_num(target.model) # number of unconstrained parameters 
    init = zeros(d_unc) 
    return StanState(init)
end

create_reference_log_potential(target::StanLogPotential, ::Inputs) = 
    target # set reference = target for first few tuning rounds

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
        stan_error(sm.lib, err, lp)
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
        stan_error(sm.lib, err, lp)
    end
    (lp[], out)
end

function stan_error(lib, err, lp)
    @warn "Treating stan error as -Inf: $(BridgeStan.handle_error(lib, err, "stan_log_density/gradient"))" maxlog=1
    lp[] = -Inf
    return nothing
end