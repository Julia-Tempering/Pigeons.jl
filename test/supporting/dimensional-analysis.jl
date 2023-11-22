# Creates a log-log plot of ESS/eval as function of dim to benchmark explorers

using AdvancedHMC, ForwardDiff
using LogDensityProblems
using LinearAlgebra

using Pigeons
using LinearRegression

using MCMCDiagnosticTools
using MCMCChains

using Statistics
using Plots 

using Random

Random.seed!(123)

abstract type LogDensity end 
(p::LogDensity)(x) = LogDensityProblems.logdensity(p, x)
LogDensityProblems.dimension(p::T) where {T <: LogDensity} = p.dim
LogDensityProblems.capabilities(::Type{T}) where {T <: LogDensity} = LogDensityProblems.LogDensityOrder{1}()
Pigeons.initialization(p::LogDensity, _, _) = zeros(p.dim)


# Define the target distribution using the `LogDensityProblem` interface
struct IsoNormal <: LogDensity
    dim::Int
end
LogDensityProblems.logdensity(p::IsoNormal, θ) = -sum(abs2, θ) / 2  # standard multivariate normal

struct Funnel <: LogDensity 
    dim::Int
end
function LogDensityProblems.logdensity(p::Funnel, z) 
    # z = (y, x[1], .., x[dim-1])
    @assert length(z) == p.dim
    sum = 0.0
    y = z[1] 
    sum += logpdf(Normal(0.0, 3.0), y)
    sigma_for_others = exp(y/2.0)
    for i in 2:p.dim
        sum += logpdf(Normal(0.0, sigma_for_others), z[i])
    end
    return sum
end

# Based off AdvancedHMC README:
function nuts(logp)
    D = logp.dim
    # Choose parameter dimensionality and initial parameter value
    initial_θ = randn(D)
    
    # Set the number of samples to draw and warmup iterations
    n_samples, n_adapts = 2_000, 1_000

    # Define a Hamiltonian system
    metric = DiagEuclideanMetric(D)
    hamiltonian = Hamiltonian(metric, logp, ForwardDiff)

    # Define a leapfrog solver, with initial step size chosen heuristically
    initial_ϵ = find_good_stepsize(hamiltonian, initial_θ)
    integrator = Leapfrog(initial_ϵ)

    # Define an HMC sampler, with the following components
    #   - multinomial sampling scheme,
    #   - generalised No-U-Turn criteria, and
    #   - windowed adaption for step-size and diagonal mass matrix
    kernel = HMCKernel(Trajectory{MultinomialTS}(integrator, GeneralisedNoUTurn()))
    adaptor = StanHMCAdaptor(MassMatrixAdaptor(metric), StepSizeAdaptor(0.8, integrator))

    # Run the sampler to draw samples from the specified Gaussian, where
    #   - `samples` will store the samples
    #   - `stats` will store diagnostic statistics for each sample
    samples, stats = sample(hamiltonian, kernel, initial_θ, n_samples, adaptor, n_adapts; progress=false)


    # next: compute logp on each sample
    vs = map(s -> LogDensityProblems.logdensity(logp, s), samples)

    # estimate cost per ESS
    n_steps = sum(map(s -> s.n_steps, stats))
    ess_value = compute_ess(vs)
    return D, n_steps, ess_value
end

function single_chain_pigeons_mvn(logp, explorer)
    pt = pigeons(;
        target = logp,
        reference = logp,
        n_chains = 1, 
        seed = rand(Int),
        show_report = false,
        explorer, 
        record = [traces],
        extractor = Pigeons.LogPotentialExtractor()
    )
    vs = get_sample(pt, 1) 
    @show ess_value = compute_ess(vs) 
    @show n_steps = Pigeons.explorer_n_steps(pt)[1]
    return n_steps, ess_value
end


function auto_mala(logp)
    D = logp.dim
    explorer = Pigeons.AutoMALA(exponent_n_refresh = 0.35)
    n_steps, ess_value = single_chain_pigeons_mvn(logp, explorer)
    return D, n_steps, ess_value
end


sparse_slicer(logp) = slicer(logp, true) 
dense_slicer(logp) = slicer(logp, false)

function slicer(logp, sparse::Bool)
    D = logp.dim
    explorer = Pigeons.SliceSampler() 
    n_steps, ess_value = single_chain_pigeons_mvn(logp, explorer)
    return (sparse ? 1 : D), n_steps, ess_value
end

function compute_ess(vs) 
    ess_df = ess(Chains(vs, [:V]))
    result = ess_df.nt.ess[1]
    if result < 100 
        @warn "Low ESS: $result"
    end
    return result
end

function scaling_plot(
            max; 
            n_replicates = 1, 
            sampling_fcts = [
                sparse_slicer, 
                dense_slicer, 
                nuts, 
                auto_mala],
            logp_type = IsoNormal)
    cost_plot = plot()
    ess_plot = plot()
    data = Dict()
    for sampling_fct in sampling_fcts
        sampler_symbol = Symbol(sampling_fct)
        sampler_name = String(sampler_symbol)
        println()
        println("Sampler: $(sampler_name)")
        dims = Float64[]
        costs = Float64[]
        ess = Float64[]
        for i in 0:max
            @show D = 2^i
            logp = logp_type(D)
            @time replicates = [sampling_fct(logp) for j in 1:n_replicates]
            push!(dims, D)

            cost_and_ess = mean(
                map(replicates) do replicate 
                    @show cost_per_step, n_steps, ess_value = replicate 
                    cost = cost_per_step * n_steps / ess_value
                    [cost, ess_value]
                end
            )

            push!(costs, cost_and_ess[1])
            push!(ess, cost_and_ess[2])
        end
        sampler_name = String(Symbol(sampling_fct))
        plot!(cost_plot, dims, costs, 
                xaxis=:log, yaxis=:log, 
                legend = :outertopleft,
                xlabel = "dimensionality", 
                ylabel = "evals per ESS", 
                label = sampler_name)
        plot!(ess_plot, dims, ess, 
                xaxis=:log, yaxis=:log, 
                legend = :outertopleft,
                xlabel = "dimensionality", 
                ylabel = "ESS", 
                label = sampler_name) 
        data[sampler_symbol] = (; dims, costs)
    end

    filename_prefix = "benchmarks/$logp_type/scalings_nrep=$(n_replicates)_max=$max"

    slopes = Dict()
    mkpath("benchmarks/$logp_type")
    open("$filename_prefix.txt", "w") do io
        for (k, v) in data 
            xs = log.(v.dims)
            ys = log.(v.costs)
            slope = LinearRegression.slope(linregress(xs, ys))[1]
            slopes[k] = slope
            println(io, "$k: $slope")
        end
    end

    return (; logp_type, n_replicates, max, data, slopes, cost_plot, ess_plot)
end

function save_dim_analysis_plots(tuple)
    filename_prefix = "benchmarks/$(tuple.logp_type)/scalings_nrep=$(tuple.n_replicates)_max=$(tuple.max)"
    savefig(tuple.cost_plot, "$filename_prefix.pdf")
    savefig(tuple.ess_plot, "$(filename_prefix)_ess.pdf")
end