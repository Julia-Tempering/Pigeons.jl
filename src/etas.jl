#' Compute η
#'
#' Computes η given ϕ and β
#'
#' @param ϕ Array (K - 1, 2) containing knot parameters
#' @param β Vector of N+1 schedules
#'
function computeEtas(ϕ, β)
    if ϕ != [0.5 0.5]
        error("ϕ must be [0.5 0.5]")
    end

    out = zeros(length(β), 2)
    for i in 1:length(β)
        out[i, 1] = 1.0 - β[i]
        out[i, 2] = β[i]
    end

    return out
end


# Old code that might be useful if you want to consider non-linear annealing paths
# K = size(ϕ)[1] + 1
# η = vcat([1. 0.], ϕ, [0. 1.])
# annealed_η = zeros(size(β)[1], 2) # Output of η for each chain (N+1, 2)
# tmp = ones(size(annealed_η))
# for k in 1:K
#     annealed_η += ((β .>= (k - 1)/K) .& (β .< k/K)) .* reshape(
#         (k .- K * β) .* η[k, :]' .* tmp .+ (β * K .- k .+ 1) .* η[k + 1, :]' .* tmp, :, 2) # Vectorized operation
# end
# annealed_η[end, :] = [0., 1.] # End at target
# return annealed_η