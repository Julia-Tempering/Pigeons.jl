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
    current = current_position(pair_swapper, replica)

    # compute "pre-involution" i.e. moved point s.t. we have not checked yet that the involutive prop holds
    fwd_obj_and_deriv = objective_and_derivative(pair_swapper, replica, partner_chain, replica.chain)
    bwd_obj_and_deriv = objective_and_derivative(pair_swapper, replica, replica.chain, partner_chain)

    proposed = pre_involution(fwd_obj_and_deriv, current) # proposed is NaN if solution not found
    reversed = pre_involution(bwd_obj_and_deriv, proposed)

    checked = isapprox(current, reversed; atol = fused_swap_tol[]) # if NaN, 'checked' and hence 'fused' will be false
    fused = checked && proposed != current # are use doing a 'fused move' (where both x and beta change)? otherwise, classical swap where only beta's are exchanged

    if !fused # then use classical ratio:
        log_ratio = log_unnormalized_ratio(log_potentials, partner_chain, replica.chain, replica.state)
        move!(pair_swapper, replica, current)
        return FusedStat(log_ratio, rand(replica.rng), current)
    end

    W_my_prime = bwd_obj_and_deriv[2]
    W_partner_prime = fwd_obj_and_deriv[2] 

    log_ratio = log(W_my_prime(current)) - log(W_partner_prime(proposed)) - log(transport_deriv(pair_swapper, current))
    
    # go back to current point, will do the actual moving after the accept-reject step
    move!(pair_swapper, replica, current)
    return FusedStat(log_ratio, rand(replica.rng), proposed)
end

function transport_deriv(pair_swapper, current)
    function fct(point)
        
    end
end

function objective_and_derivative(pair_swapper::FusedSwap, replica::Replica, partner_chain, my_chain)
    current_height = pair_swapper.log_potentials[my_chain](replica.state) 
    transported_height = transport_height(pair_swapper, partner_chain, my_chain, current_height)
    function objective(point)
        move!(pair_swapper, replica, point)
        return pair_swapper.log_potentials[partner_chain](replica.state) - transported_height
    end
    deriv(point) = ForwardDiff.derivative(objective, point)
    return (objective, deriv) 
end

function pre_involution(obj_and_deriv, start_point)
    problem = ZeroProblem(obj_and_deriv, start_point)
    return solve(problem, atol = fused_swap_tol[] / 2.0)  
end

function move!(pair_swapper::FusedSwap, replica::Replica, to)
    # move by delta in place along the flow
end

function current_position(pair_swapper::FusedSwap, replica::Replica)

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