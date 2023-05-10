

#=

Cf on increasing d, the behaviour of V(X)

- adaptive hit and run 
- HMC 

=#


using AdvancedHMC, ForwardDiff
using LogDensityProblems
using LinearAlgebra

using MCMCDiagnosticTools
using MCMCChains

# Define the target distribution using the `LogDensityProblem` interface
struct LogTargetDensity
    dim::Int
end
LogDensityProblems.logdensity(p::LogTargetDensity, θ) = -sum(abs2, θ) / 2  # standard multivariate normal
LogDensityProblems.dimension(p::LogTargetDensity) = p.dim
LogDensityProblems.capabilities(::Type{LogTargetDensity}) = LogDensityProblems.LogDensityOrder{0}()



function nuts(D)
    # Choose parameter dimensionality and initial parameter value
    initial_θ = rand(D)
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
    samples, stats = sample(hamiltonian, proposal, initial_θ, n_samples, adaptor, n_adapts; progress=true)

    # next: compute logp on each sample
    vs = map(s -> LogDensityProblems.logdensity(logp, s), samples)

    n_steps = sum(map(s -> s.n_steps, stats))


    ess_df = ess(Chains(vs, [:V]))
    ess_value = ess_df.nt.ess[1]

    return D*n_steps/ess_value
end

dims = []
costs = []

using Statistics

for i in 0:10
    D = 2^i
    replicates = [nuts(D) for j in 1:10]
    push!(dims, D)
    push!(costs, mean(replicates))
end

using Plots 
p = plot(dims, costs, xaxis=:log, yaxis=:log)