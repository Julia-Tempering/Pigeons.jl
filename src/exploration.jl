"""
    LocalExploration(States, Kernels, optimreference_round, modref_means, modref_stds, 
        modref_covs, full_covariance, prior_sampler, chain_stds, n_explore)
        ChainAcceptance = Vector{Int64}(undef, length(States))

Perform one local exploration move. `State` is the state from the **one** 
previous scan, which is of size N+1[dim_x].
"""
function LocalExploration(States, Kernels, optimreference_round, modref_means, modref_stds, 
    modref_covs, full_covariance, prior_sampler, chain_stds, n_explore)
    ChainAcceptance = Vector{Int64}(undef, length(States)) # Length N+1: Binary indicators

    if (!optimreference_round)
        if (!isnothing(prior_sampler))
            out_reference = prior_sampler()
            out_reference = [out_reference]
            ChainAcceptance = [1.0 for _ in 1:length(ChainAcceptance)] # Reference sampling is always accepted
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

    return (
        out             = out,
        ChainAcceptance = ChainAcceptance)
end


"""
    setKernels(potential, Etas)

Set the local exploration kernels given the `potential` and the annealing 
parameters, `Etas`.
"""
function setKernels(potential, Etas)
    kernels = Vector{SS}(undef, size(Etas)[1])
    for i in 1:size(Etas)[1]
        loglik = (x) -> potential(x, Etas[i, :]) # Neg. log *density* (*not* the log-likelihood!)
        kernels[i] = SS(loglik) # Use slice sampling defaults
    end
    return kernels
end