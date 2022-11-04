# State: The state from the one previous scan. Of size: N+1 [dim_x]
function DEOscan(potential, State, Index, Lift, Etas, n, N, Kernels, Schedule, optimreference_round, modref_means, modref_stds, modref_covs, full_covariance, prior_sampler, chain_stds, HMC_std_multiplier, explore_target, n_explore) 
    
    # Local exploration phase    
    newState_full = LocalExploration(State, Kernels, optimreference_round, modref_means, modref_stds, modref_covs, full_covariance, prior_sampler, chain_stds, HMC_std_multiplier, explore_target, n_explore)
    newState = newState_full.out
    ChainAcceptance = newState_full.ChainAcceptance

    newEnergy = potential.(newState, eachrow(Etas)) # -log([π_t_0(x^0), π_t_1(x^1), ..., π_t_N(x^N)]) : length N+1
    newEnergy1 = potential.(newState[2:end], eachrow(Etas[1:end-1, :])) # -log([π_t_0(x^1), π_t_1(x^2), ..., π_t_{N-1}(x^N)]) : length N
    newEnergy2 = potential.(newState[1:end-1], eachrow(Etas[2:end, :])) # -log([π_t_1(x^0), π_t_2(x^1), ..., π_t_N(x^{N-1})]) : length N
    newIndex = copy(Index)
    newLift = copy(Lift)

    # Communication phase
    # Compute acceptance probability
    Acceptance = acceptanceprobability(newEnergy, newEnergy1, newEnergy2)

    # Update Rejection
    Rejection = 1 .- Acceptance # Vectorized
    # Odd/Even swaps
    isodd(n) ? (P = 1 :2:N) : (P = 2:2:N)
    for i ∈ P
        # Swap states i and i+1
        i_1, i_2 = findfirst(Index .== i), findfirst(Index .== i+1)
        if rand(Bernoulli(Acceptance[i]))
            # Perform swap
            newState[i], newState[i+1] = newState[i+1], newState[i]
            newEnergy[i], newEnergy[i+1] = newEnergy[i+1], newEnergy[i]
            newIndex[i_1], newIndex[i_2] = i+1, i
        end
    end

    for j ∈ 1:N+1
        if newIndex[j] != Index[j]+Lift[j]
            newLift[j] = -Lift[j] # Change direction
        end
    end
    return (
        State           = newState, 
        Energy          = newEnergy, 
        Index           = newIndex, 
        Lift            = newLift, 
        Rejection       = Rejection,
        ChainAcceptance = ChainAcceptance)
end
