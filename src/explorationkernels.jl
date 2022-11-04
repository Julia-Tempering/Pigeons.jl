# State: The state from the one previous scan. Of size: N+1 [dim_x]
function LocalExploration(States, Kernels, optimreference_round, modref_means, modref_stds, modref_covs, full_covariance, prior_sampler, chain_stds, HMC_std_multiplier, explore_target, n_explore)
    ChainAcceptance = Vector{Int64}(undef, length(States)) # Binary vector of length N+1: Did we successfully sample a new state (accept = 1)?

    if (!optimreference_round)
        if (!isnothing(prior_sampler))
            out_reference = prior_sampler()
            out_reference = [out_reference]
            ChainAcceptance = [1.0 for _ in 1:length(ChainAcceptance)] # Sampling from the reference chain always results in acceptance
            out_other = slice_sample.(Kernels[2:end], States[2:end], repeat([n_explore], size(States[2:end])[1]))
            out_other = map((i) -> out_other[i][end], 1:length(out_other))
            out = vcat(out_reference, out_other)
        else # No prior sampler
            out = slice_sample.(Kernels, States, repeat([n_explore], size(States)[1]))
            out = map((i) -> out[i][end], 1:length(out)) 
            ChainAcceptance = [1.0 for _ in 1:length(ChainAcceptance)]
            # Vector of length N+1, containing vectors of length dim_x
        end
    else # The reference distribution is being tuned in this round
        if !full_covariance # Mean-field approximation
            out_reference = Vector{Float64}(undef, length(modref_means))
            for j in 1:length(modref_means) # Use an efficient normal distribution sampler
                out_reference[j] = rand(Normal(modref_means[j], modref_stds[j]), 1)[1]
            end
        else # Full covariance matrix
            out_reference = rand(MvNormal(modref_means, modref_covs))    
        end
        
        out_reference = [out_reference]
        ChainAcceptance[1] = 1
        out_other = slice_sample.(Kernels[2:end], States[2:end], repeat([n_explore], size(States[2:end])[1]))
        out_other = map((i) -> out_other[i][end], 1:length(out_other))
        ChainAcceptance = [1.0 for _ in 1:length(ChainAcceptance)]
        out = vcat(out_reference, out_other)
    end

    if !explore_target
        # Not an efficient implementation at the moment because we are overwriting previously done (unnecesary) exploration
        out[end] = copy(States[end])
    end

    return (
        out             = out,
        ChainAcceptance = ChainAcceptance)
end