using ForwardDiff
using StaticArrays
using Statistics
using Distributions

# function computeEtas(ϕ, β)
#     # ϕ is an array K - 1, 2
#     K = size(ϕ)[1] + 1
#     η = vcat([1. 0.], ϕ, [0. 1.])
#     annealed_η = zeros(size(β)[1], 2)
#     tmp = ones(size(annealed_η))
#     for k in 1:K
#         annealed_η += ((β .>= (k - 1)/K) .& (β .< k/K)) .* reshape(
#             (k .- K * β) .* η[k, :]' .* tmp .+ (β * K .- k .+ 1) .* η[k + 1, :]' .* tmp, :, 2)
#     end
#     annealed_η[end, :] = [0., 1.]
#     return annealed_η
# end

function etasZ(ϕ, β)
    η = computeEtas(ϕ, β)
    N = size(β)[1]
    zj = zeros(N, 2)
    for i in 1:N
        if i == 1
            zj += (1:N .== 1) * reshape(η[1, :] + η[2,:], 1, 2)
        elseif i == N
            zj += (1:N .== N) * reshape(η[end, :] - η[(end -1), :], 1, 2)
        else
            zj += (1:N .== i) * reshape(2 * η[i, :] - η[i - 1, :] - η[i + 1, :], 1, 2)
        end
    end
    return reshape(zj, :)
end

# function gradZ(ϕ, β)
#     f = ϕ -> (y = etasZ(ϕ, β); return y)
#     N = length(β)
#     grads = zeros((N, prod(size(ϕ))))
#     jac = ForwardDiff.jacobian(f, ϕ)
#     for i in 1:size(jac,2)
#         grads[:, i] = jac[(N * (i - 1) + 1):(N * (i - 1) + N), i]
#     end
#     return grads
# end

function gradW(ϕ, β, x, potential)
    f = ϕ -> (y = potential.(x, eachrow(computeEtas(ϕ, β))); return y)
    return -ForwardDiff.jacobian(f, ϕ)
end

function J(ϕ, β, x, potential)
    W0 = -potential.(x, repeat([1 0], size(x)[1]))
    W1 = -potential.(x, repeat([0 1], size(x)[1]))

    J = reshape([W0'; W1'], :, prod(size(g)))

    z = etasZ(ϕ, β)

    return J * z
end

function gradJ(ϕ, β, x, potential)
    f = ϕ -> (y = potential.(x, eachrow(computeEtas(ϕ, β))); return y)
    return ForwardDiff.jacobian(f, ϕ)
end

function gradientFull(ϕ, β, x, potential)
    gradw = gradW(ϕ, β, x, potential) #sum over samples, needs to be done during de-insect-ing
    J_ϕ = J(ϕ, β, x, potential)
    gradj = gradJ(ϕ, β, x, potential)

    gradw_demean = gradw - mean(gradw, 1)
    J_demean = J_ϕ - mean(J_ϕ, 1)
    grad = (gradw_demean' * J_demean)/(size(g_demean)[1] - 1) + mean(gradj, 1)

    return grad
end

V_1(x) =  -log.(0.5*pdf.(Normal(-2, 0.1),x[:, 1]) .+ 0.5*pdf.(Normal(2, 0.1),x[:, 1]))
params = [-1, 0.1]
V_0(x; params=params) =-logpdf.(Normal(params[1],params[2]),x[:, 1])

function V(x, η; params=params)
    return V_0(x; params=params) * η[1] + V_1(x) * η[2]
end

x = randn(10, 10, 3)
V_1(x)
β = 0:0.11111:1
ϕ = [0.5 0.5]
gradientFull(ϕ, β, x, V)
# η = [1 0; 0.5 0.5; 0 1]
# sn =SMatrix{3,2}(η)
# ϕ = [0.5 0.5]
# β = SVector{3}([0, 0.5, 1.])
# f = ϕ -> (y = etasZ(ϕ, β); return y)
# ForwardDiff.jacobian(f, ϕ)