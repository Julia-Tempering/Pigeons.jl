@concrete struct FusedSwap
    log_potentials
end

struct FusedStat 
    log_ratio::Float64 
    uniform::Float64
    proposed::Float64
end

const fused_swap_tol = Ref(1e-5)

function swap_stat(pair_swapper::FusedSwap, replica::Replica, partner_chain::Int) 
    # everythig will be in place, so save current location along the orbit
    current_t, mover = state_mover(pair_swapper, replica)

    T, dT = height_mover(pair_swapper, replica.chain, partner_chain)
    W_mine,  dW_mine  = log_density_slice(mover, pair_swapper.log_potentials[replica.chain])
    W_yours, dW_yours = log_density_slice(mover, pair_swapper.log_potentials[partner_chain]) 

    current_height  = W_mine(current_state)
    proposed_height = T(current_height)

    # compute "pre-involution" i.e. proposed state move s.t. we have not checked yet that the involutive property holds
    proposed_t     = pre_involution(W_yours, dW_yours, current_t,  proposed_height) 
    
    if isnan(proposed_t) # i.e. root finding in pre_involution failed
        fused = false
    else
        reversed_t = pre_involution(W_mine,  dW_mine,  proposed_t, current_height)
        checked = isapprox(current_t, reversed_t; atol = fused_swap_tol[]) # if reversed_t is NaN, 'checked' and hence 'fused' will be false
        fused = checked && proposed_t != current_t # are use doing a 'fused move' (where both x and beta change)? otherwise, classical swap where only beta's are exchanged
    end

    if !fused # then use classical ratio:
        log_ratio = log_unnormalized_ratio(log_potentials, partner_chain, replica.chain, replica.state)
        move!(mover, current_t)
        return FusedStat(log_ratio, rand(replica.rng), current_t)
    end

    log_ratio = logabs(dW_mine(current_t)) - logabs(dW_yours(proposed_t)) + logabs(dT(current_height))
    
    # go back to current point, will do the actual moving after the accept-reject step
    move!(mover, current_t)
    return FusedStat(log_ratio, rand(replica.rng), proposed_t)
end

logabs(x) = log(abs(x))

function pre_involution(W, dW, start_point, proposed_height)
    shifted_W(x) = W(x) - proposed_height
    problem = ZeroProblem((shifted_W, dW), start_point)
    return solve(problem, atol = fused_swap_tol[] / 2.0)  
end

@concrete mutable struct StateMover
    moved_t
    replica
end

function state_mover(pair_swapper::FusedSwap, replica)
    # consider set of point {exp(t) x : t in Real}
    current_t = 0.0
    mover = StateMover(current_t, replica)
    return current_t, mover
end

function move!(mover::StateMover, to)
    if to == mover.moved_t
        return 
    end
    # current replica state is cur = exp(t) x
    # you want to got to       new = exp(t') x
    # we have: new = exp(t') x = (exp(t) / exp(t)) exp(t') x = (exp(t') / exp(t)) ( exp(t) x ) = (exp(t' - t)) cur
    multiplier = exp(to - mover.current_t)
    scale!(mover.replica, multiplier)
end

function log_density_slice(mover, log_potential)
    function W(t)
        move!(mover, t) 
        return log_potential(mover.replica.state)
    end 
    function dW(t)
        move!(mover, t)
        # since the derivative of exp(t) is exp(t) this is just the directional derivative at x_t and along x_t
        return directional_derivative(log_potential, mover.replica.state, mover.replica.state) 
    end
    return W, dW
end

function directional_derivative(log_potential, x, v)
    # NB: may want to use FwdDiff with a given direction
    # seems implemented in https://github.com/JuliaDiff/SparseDiffTools.jl/blob/master/src/differentiation/jaches_products.jl#L3-L13
    # but does not have public API at the moment??? https://github.com/JuliaDiff/ForwardDiff.jl/issues/319
    gradient = gradient(log_potential, x)
    return dot(gradient, v)
end

function record_swap_stats!(pair_swapper::FusedSwap, recorders, chain1::Int, stat1, chain2::Int, stat2)
    acceptance_pr = swap_acceptance_probability(stat1, stat2)
    key1 = (chain1, chain2)
    
    record_if_requested!(recorders, :swap_acceptance_pr, (key1, acceptance_pr))
    
    # TODO: derive new normalization constant identity
    # key2 = (chain2, chain1)
    # record_if_requested!(recorders, :log_sum_ratio, (key1, stat1.log_ratio))
    # record_if_requested!(recorders, :log_sum_ratio, (key2, stat2.log_ratio)) # compute both to estimate a sandwich
end

function swap_decision(pair_swapper::FusedSwap, chain1::Int, stat1, chain2::Int, stat2)
    acceptance_pr = swap_acceptance_probability(stat1, stat2)
    uniform = chain1 < chain2 ? stat1.uniform : stat2.uniform

    # TODO: if accept, move the state using the involution

    return uniform < acceptance_pr
end