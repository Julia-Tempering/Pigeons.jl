using Pigeons
using Random
using Statistics

# Example on how to do a mix of continuous and discrete state in a custom likelihood

# Uniform where each component is s.t. abs(x_i) < 1
struct MyUniform 
    n_continuous::Int 
    n_discrete::Int
end

struct MixedState 
    continuous::Vector{Float64}
    discrete::Vector{Int}
end

(log_potential::MyUniform)(state::MixedState) =
    return in_support(state.continuous) && in_support(state.discrete) ? 0.0 : -Inf

function in_support(array) 
    for entry in array 
        if abs(entry) > 1 
            return false
        end
    end
    return true
end

# No annealing needed in this toy example
Pigeons.default_reference(log_potential::MyUniform) = log_potential

Pigeons.initialization(log_potential::MyUniform, ::AbstractRNG, ::Int) = 
    MixedState(zeros(Float64, log_potential.n_continuous), zeros(Int, log_potential.n_discrete))

Pigeons.@auto struct MixedSliceSampler
    sampler
end

# Apply the slice sampler to both continuous and discrete components
function Pigeons.step!(mixed_explorer::MixedSliceSampler, replica, shared)
    explorer = mixed_explorer.sampler
    log_potential = Pigeons.find_log_potential(replica, shared.tempering, shared)
    cached_lp = -Inf
    for _ in 1:explorer.n_passes
        cached_lp = Pigeons.slice_sample!(explorer, replica.state.continuous, log_potential, cached_lp, replica)
        cached_lp = Pigeons.slice_sample!(explorer, replica.state.discrete, log_potential, cached_lp, replica)
    end
end

Pigeons.default_explorer(::MyUniform) = MixedSliceSampler(SliceSampler())
Pigeons.extract_sample(state::MixedState, log_potential) = [copy(state.continuous); copy(state.discrete)]

# Example: two continuous components, two discrete components
pt = pigeons(target = MyUniform(2, 2), n_rounds = 15, n_chains = 2, record = [online])

@assert isapprox(mean(pt), zeros(4); atol=0.1)
@assert isapprox(var(pt), [1/3, 1/3, 2/3, 2/3]; atol=0.1)
