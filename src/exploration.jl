"""
$TYPEDSIGNATURES

Perform one local exploration move. `state` is the state from the **one** 
previous scan, which is of size N+1[dim_x].
"""
function local_exploration(states, kernels, optimreference_round, modref_means, modref_stds, 
                          modref_covs, full_covariance, prior_sampler, n_explore)
    
    chainacceptance = Vector{Int64}(undef, length(states)) # Length N+1: Binary indicators

    if (!optimreference_round)
        if (!isnothing(prior_sampler))
            out_reference = prior_sampler()
            out_reference = [out_reference]
            chainacceptance = [1.0 for _ in 1:length(chainacceptance)] # Reference sampling is always accepted
            out_other = slice_sample.(kernels[2:end], states[2:end], repeat([n_explore], size(states[2:end])[1]))
            out_other = map((i) -> out_other[i][end], 1:length(out_other))
            out = vcat(out_reference, out_other)
        else # No prior sampler
            out = slice_sample.(kernels, states, repeat([n_explore], size(states)[1]))
            out = map((i) -> out[i][end], 1:length(out)) 
            chainacceptance = [1.0 for _ in 1:length(chainacceptance)]
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
        chainacceptance[1] = 1
        out_other = slice_sample.(kernels[2:end], states[2:end], repeat([n_explore], size(states[2:end])[1]))
        out_other = map((i) -> out_other[i][end], 1:length(out_other))
        chainacceptance = [1.0 for _ in 1:length(chainacceptance)]
        out = vcat(out_reference, out_other)
    end

    return (; out, chainacceptance)
end


"""
$TYPEDSIGNATURES

Set the local exploration kernels given the `potential` and the annealing 
parameters, `etas`.
"""
function setkernels(potential, etas)
    kernels = Vector{SS}(undef, size(etas)[1])
    for i in 1:size(etas)[1]
        loglik = (x) -> potential(x, etas[i, :]) # Neg. log *density* (*not* the log-likelihood!)
        kernels[i] = SS(loglik) # Use slice sampling defaults
    end
    return kernels
end