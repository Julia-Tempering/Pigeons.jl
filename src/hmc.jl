# Comment on the current HMC defaults:
# Momentum: MVN(0, (var(x|y))^(-1))
# ϵ = 0.1
# L = 10 (i.e., ten leapfrog steps)

using Base: Int64, Float64
using Distributions
using ForwardDiff

struct HMC
    potential
    grad
    ϵ
    L
end

# state is a vector of size dim_x. It is the state from the previous scan.
# chain_std is the estimated standard deviation of observations in the given chain.
function samplerHMC(state, h::HMC, nsamps::Int64, chain_std, HMC_std_multiplier)
    if (nsamps > 1) 
        error("'nsamps' > 1 is not yet implemented for the HMC sampler.")
    end

    chain_std = HMC_std_multiplier .* chain_std # If multiplier > 1, explores the state space more

    current_q = deepcopy(state) # State
    current_p = Vector{Float64}(undef, length(chain_std)) # Momentum
    ChainAcceptance = 0
    M = diagm(1 ./ chain_std.^2) # Inverse of variances (diagonal matrix)
    M_inv = diagm(chain_std.^2) # Variances (diagonal matrix)
    for j in 1:length(current_p)
        current_p[j] = rand(Normal(0.0, 1/chain_std[j])) # Update/sample momentum
    end

    for _ in 1:nsamps
        p, q = leapfrog(h, current_p, current_q, M_inv) # New (proposed) states
        current_q_full = acceptance(h, p, q, current_p, current_q, M_inv)
        current_q = deepcopy(current_q_full.state)
        ChainAcceptance = deepcopy(current_q_full.ChainAcceptance)
        for j in 1:length(current_p)
            current_p[j] = rand(Normal(0.0, 1/chain_std[j]))
        end
    end
    return (
        current_q       = current_q,
        ChainAcceptance = ChainAcceptance)
end

function leapfrog(h::HMC, p, q, M_inv)
    p_old = deepcopy(p)
    q_old = deepcopy(q)

    p -= h.ϵ * h.grad(q)/2 # Update momentum by a half-step (negative sign because the gradient is taken on the *negative* log density)
    for i in 1:h.L
        q += h.ϵ * M_inv * p # Update state by a full-step
        if h.potential(q) == Inf # -log density == Inf --> density == 0
            p = deepcopy(p_old)
            q = deepcopy(q_old)
            return p, q # Exit early
        end 

        if i != h.L
            p -= h.ϵ * h.grad(q) # Update momentum by a full-step
        end
    end
    p -= h.ϵ * h.grad(q)/2 # Update momentum by a half-step (negative sign for the same reason as above)
    return p, q
end

function acceptance(h::HMC, p, q, current_p, current_q, M_inv)
    current_U = h.potential(current_q) # Old state
    current_K = (current_p' * M_inv * current_p)/2 # Old momentum (- log of Normal(0, M) density)
    proposed_U = h.potential(q) # New state
    proposed_K = (p' * M_inv * p)/2 # New momentum

    if rand() < exp(current_U - proposed_U + current_K - proposed_K)
        return (
            state           = q,
            ChainAcceptance = 1)
    else
        return (
            state           = current_q,
            ChainAcceptance = 0)
    end
end