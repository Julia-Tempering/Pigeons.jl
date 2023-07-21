using Pigeons
using Distributions 
using DynamicPPL
using Random
using LogExpFunctions
using MCMCChains
using StatsPlots

observed_range_squared(x) = (maximum(x) - minimum(x))^2 # copied

@model function galaxy(y)
    K = 3
    α = 1.0 # return to 0.01
    b_0 = median(y)
    B_0 = observed_range_squared(y)
    c_0 = 2.0
    C_0 = 1.0
    n = length(y)
    γ = [α/K for k in 1:K] # is this correct? compare to stan code: (alpha = ones(K)/alpha_0)
    η ~ Dirichlet(γ)

    μ = Vector{Float64}(undef, K)
    inv_σ2 = Vector{Float64}(undef, K)
    for k in 1:K 
        μ[k] ~ Normal(b_0, B_0)
        inv_σ2[k] ~ Gamma(c_0, 1/C_0)
    end
    
    log_eta = log.(η) # cache log calculation
    if DynamicPPL.leafcontext(__context__) !== DynamicPPL.PriorContext()
        for i in 1:n 
            lps = log_eta
            for k in 1:K 
                lps[k] += logpdf(Normal(μ[k], sqrt(1/inv_σ2[k])), y[i])
            end  
            DynamicPPL.@addlogprob! LogExpFunctions.logsumexp(lps)
        end
    end
    return y
end 

function galaxy_model()
    data = [
        9172, 9350, 9483, 9558, 9775, 10227, 10406, 16084, 16170, 18419, 
        18552, 18600, 18927, 19052, 19070, 19330, 19343, 19349, 19440, 19473, 
        19529, 19541, 19547, 19663, 19846, 19856, 19863, 19914, 19918, 19973,
        19989, 20166, 20175, 20179, 20196, 20215, 20221, 20795, 20875, 21492,
        21921, 22209, 20415, 20821, 20986, 21701, 21960, 22242, 20629, 20846,
        21137, 21814, 22185, 22249, 22314, 22746, 22914, 23263, 22374, 22747,
        23206, 23484, 22495, 22888, 23241, 23538, 23542, 23666, 23706, 23711, 
        24129, 24285, 24289, 24366, 24717, 24990, 25633, 26960, 26995, 32065, 
        32789, 34279
    ]/1_000
    return galaxy(data)
end 

model = galaxy_model()
pt = pigeons(target = TuringLogPotential(model), record = [traces])
plot(Chains(Pigeons.sample_matrix(pt), Pigeons.variable_names(pt)))