using Pigeons
using JuliaBUGS
using LogDensityProblems
using Random
using Distributions

struct JuliaBUGSPotential
    # Compiled BUGS model for computing log density
    model::JuliaBUGS.BUGSModel
    # Distribution information for each node for checking support
    distributions::Vector{Distributions.Distribution}
    # Priors for sample_iid!
    priors::Vector{Distributions.Distribution}
end

# Calculate log density
function (log_potential::JuliaBUGSPotential)(x)
    for i in eachindex(x)
        # Check support
        if !Distributions.insupport(log_potential.distributions[i], x[i])
            return -Inf64
        end
    end
    return try
        Base.invokelatest(LogDensityProblems.logdensity, log_potential.model, x)
    catch e
        -Inf64
    end
end

# Extract distributions from the model.
# Revise the code structure that JuliaBUGS uses for calculating/extracting node-related prooperties.
# https://github.com/TuringLang/JuliaBUGS.jl/blob/master/src/model.jl
function extract_distributions(model::JuliaBUGS.BUGSModel)
    sorted_nodes = model.sorted_nodes
    g = model.g
    vi = model.varinfo
    parameters = model.parameters
    distributions = Vector{Distribution}()
    for vn in parameters
        (; node_function, node_args, loop_vars) = g[vn]
        args = JuliaBUGS.prepare_arg_values(node_args, vi, loop_vars)
        dist = Base.invokelatest(node_function; args...)
        push!(distributions, dist)
    end
    return distributions
end

# Sample from priors
function Pigeons.sample_iid!(log_potential::JuliaBUGSPotential, replica, shared)
    priors = log_potential.priors
    for i in eachindex(priors)
        replica.state[i] = rand(replica.rng, priors[i])
    end
end

# Prepare initialization
function prior_sampling_helper(priors::Vector{Distributions.Distribution})
    vec = []
    for i in eachindex(priors)
        push!(vec,rand(priors[i]))
    end
    return vec
end
