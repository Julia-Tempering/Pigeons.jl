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

# Define the target distribution using the `LogDensityProblem` interface
struct LogTargetDensity
    dim::Int
end
LogDensityProblems.logdensity(p::LogTargetDensity, θ) = -sum(abs2, θ) / 2  # standard multivariate normal
LogDensityProblems.dimension(p::LogTargetDensity) = p.dim
LogDensityProblems.capabilities(::Type{LogTargetDensity}) = LogDensityProblems.LogDensityOrder{0}()

# Based off AdvancedHMC README:
function nuts(D)
    # Choose parameter dimensionality and initial parameter value
    initial_θ = randn(D)
    logp = LogTargetDensity(D)

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
    proposal = NUTS{MultinomialTS, GeneralisedNoUTurn}(integrator)
    adaptor = StanHMCAdaptor(MassMatrixAdaptor(metric), StepSizeAdaptor(0.8, integrator))

    # Run the sampler to draw samples from the specified Gaussian, where
    #   - `samples` will store the samples
    #   - `stats` will store diagnostic statistics for each sample
    samples, stats = sample(hamiltonian, proposal, initial_θ, n_samples, adaptor, n_adapts; progress=false)

    # next: compute logp on each sample
    vs = map(s -> LogDensityProblems.logdensity(logp, s), samples)

    # estimate cost per ESS
    n_steps = sum(map(s -> s.n_steps, stats))
    ess_value = compute_ess(vs)
    return D, n_steps, ess_value
end

function single_chain_pigeons_mvn(D, explorer)
    pt = pigeons(;
        target = toy_mvn_target(D),
        n_chains = 1, 
        seed = rand(Int),
        show_report = false,
        explorer, 
        record = [traces],
        trace_type = :log_potential
    )
    vs = get_sample(pt, 1) 
    @show ess_value = compute_ess(vs) 
    @show n_steps = Pigeons.explorer_n_steps(pt)[1]
    return n_steps, ess_value
end


function auto_mala(D::Int)
    explorer = Pigeons.AutoMALA(exponent_n_refresh = 0.35)
    n_steps, ess_value = single_chain_pigeons_mvn(D, explorer)
    return D, n_steps, ess_value
end


sparse_slicer(D) = slicer(D, true) 
dense_slicer(D) = slicer(D, false)

function slicer(D, sparse::Bool)
    explorer = Pigeons.SliceSampler() 
    n_steps, ess_value = single_chain_pigeons_mvn(D, explorer)
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
            max, 
            n_replicates = 1, 
            sampling_fcts = [
                sparse_slicer, 
                dense_slicer, 
                nuts, 
                auto_mala])
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
            @time replicates = [sampling_fct(D) for j in 1:n_replicates]
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

    filename_prefix = "benchmarks/scalings_nrep=$(n_replicates)_max=$max"

    slopes = Dict()
    mkpath("benchmarks")
    open("$filename_prefix.txt", "w") do io
        for (k, v) in data 
            xs = log.(v.dims)
            ys = log.(v.costs)
            slope = LinearRegression.slope(linregress(xs, ys))[1]
            slopes[k] = slope
            println(io, "$k: $slope")
        end
    end

    # savefig(cost_plot, "$filename_prefix.pdf")
    # savefig(ess_plot, "$(filename_prefix)_ess.pdf")

    return slopes, cost_plot, ess_plot
end