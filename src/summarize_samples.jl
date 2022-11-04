include("get_chain_states.jl")

# Note: This function does not seem to be used anywhere!
function summarize_samples(obj)
    means = Vector{Vector{Float64}}(undef, obj.N+1)
    stds = Vector{Vector{Float64}}(undef, obj.N+1)
    for n in 1:(obj.N+1)
        chain_states = get_chain_states(obj, n)
        means[n] = mean(chain_states)
        stds[n] = std(chain_states)
    end

    return(means = means,
           stds  = stds
    )
end