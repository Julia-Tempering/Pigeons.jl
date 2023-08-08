using Pigeons
using Random
import Base.@kwdef

# A 2D, base_length x base_length Ising model, p(state) ∝ exp(-beta H(state))
@kwdef struct IsingLogPotential 
    beta::Float64 = 1.0
    base_length::Int = 5 # number of binary variables = base_length^2
end

function base_length(matrix::BitMatrix) 
    n_rows, n_cols = size(matrix) 
    @assert n_rows == n_cols 
    return n_rows 
end

mutable struct IsingState 
    matrix::BitMatrix 
    sum_pair_products::Int # maintain a cache of "sum_{pair x1, x2}  spin(x1) * spin(x2)"
    base_length::Int
end
function IsingState(matrix::BitMatrix)
    result = IsingState(matrix, 0, base_length(matrix))
    result.sum_pair_products = recompute_sum_pair_products(result) 
    return result
end

function recompute_sum_pair_products(state::IsingState) 
    sum = 0
    for i in 1:state.base_length
        for j in 1:state.base_length
            sum += sign(state.matrix[i,j]) * sum_neighbours(state, i, j)
        end
    end
    return sum/2
end

# Flip entry i, j and update the cache in O(1) time
function flip!(state::IsingState, i::Int, j::Int)
    sum_neighbours_pairs_before = sign(state.matrix[i, j]) * sum_neighbours(state, i, j) 
    state.matrix[i, j] = !state.matrix[i, j]
    sum_neighbours_pairs_after  = sign(state.matrix[i, j]) * sum_neighbours(state, i, j)
    difference = sum_neighbours_pairs_after - sum_neighbours_pairs_before
    state.sum_pair_products += difference 
    return nothing
end

# sample all binary variable i.i.d. Bern(1/2)
function iid_bernoulli!(state::IsingState, rng)
    @assert recompute_sum_pair_products(state) == state.sum_pair_products
    for i in 1:state.base_length
        for j in 1:state.base_length 
            state.matrix[i, j] = rand(rng, Bool)
        end
    end
    state.sum_pair_products = recompute_sum_pair_products(state)
    return nothing
end

sign(entry::Bool) = entry ? +1 : -1
sum_neighbours(s::IsingState, i, j) = sum_neighbours_row(s, i, j) + sum_neighbours_col(s, i, j)
sum_neighbours_row(s::IsingState, i, j) = sign(s.matrix[wrap(i-1, s.base_length), j]) + sign(s.matrix[wrap(i+1, s.base_length), j])
sum_neighbours_col(s::IsingState, i, j) = sign(s.matrix[i, wrap(j-1, s.base_length)]) + sign(s.matrix[i, wrap(j+1, s.base_length)])
wrap(i, L) = 
    if i == 0
        L 
    elseif i == L + 1 
        1 
    else 
        i 
    end 

# Make IsingLogPotential conform the log_potential informal interface
(log_potential::IsingLogPotential)(state::IsingState) = log_potential.beta * state.sum_pair_products

# Reference distribution uses beta = 0...
Pigeons.default_reference(log_potential::IsingLogPotential) = IsingLogPotential(0.0, log_potential.base_length)
# ... so that we can do i.i.d. sampling of Bernoullis at the reference:
function Pigeons.sample_iid!(reference_log_potential::IsingLogPotential, replica, shared)
    @assert reference_log_potential.beta == 0.0
    iid_bernoulli!(replica.state, replica.rng)
end

# Initialization: all entries to zeros (falses)
Pigeons.initialization(log_potential::IsingLogPotential, ::AbstractRNG, ::Int) = IsingState(falses(log_potential.base_length, log_potential.base_length))

# MCMC explorer 
# This struct should not contain state that is replica-specific 
#     and/or changed in the inner sampling loop (use an Augmentation if 
#     the explorer needs replica-specific auxiliary state information)
@kwdef struct IsingMetropolis
    n_steps::Int = 3
end 

Pigeons.default_explorer(lp::IsingLogPotential) = IsingMetropolis()

# Perform explorer MCMC step
function Pigeons.step!(explorer::IsingMetropolis, replica, shared)
    # Note: the log_potential is an InterpolatedLogPotential between two IsingLogPotential's
    log_potential = Pigeons.find_log_potential(replica, shared.tempering, shared)
    for k in 1:explorer.n_steps
        for i in 1:replica.state.base_length 
            for j in 1:replica.state.base_length
                # propose a change and record the change in log probability
                log_pr_before = log_potential(replica.state)
                flip!(replica.state, i, j) 
                log_pr_after = log_potential(replica.state) 
                # accept-reject step 
                accept_ratio = exp(log_pr_after - log_pr_before) 
                if accept_ratio < 1 && rand(replica.rng) > accept_ratio 
                    # reject: revert the move we just proposed
                    flip!(replica.state, i, j) 
                end # (nothing to do if accept, we work in-place)
            end
        end
    end
end
