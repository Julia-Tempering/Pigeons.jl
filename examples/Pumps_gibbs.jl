include("../src/explorer/JuliaBUGSGibbsSampler.jl")

# Pumps example in 
# https://github.com/TuringLang/JuliaBUGS.jl/blob/master/src/BUGSExamples/Volume_1/02_Pumps.jl
model_def = @bugs begin
    for i in 1:N
        theta[i] ~ dgamma(alpha, beta)
        lambda[i] = theta[i] * t[i]
        x[i] ~ dpois(lambda[i])
    end
    alpha ~ dexp(1)
    beta ~ dgamma(0.1, 1.0)
end

model_def_prior = @bugs begin
    for i in 1:N
        theta[i] ~ dgamma(alpha, beta)
    end
    alpha ~ dexp(1)
    beta ~ dgamma(0.1, 1.0)
end

data = (
    t = [94.3, 15.7, 62.9, 126, 5.24, 31.4, 1.05, 1.05, 2.1, 10.5],
    x = [5, 1, 5, 14, 3, 19, 1, 1, 4, 22],
    N = 10
)

data_prior = (
    t = Float64[],
    x = Int64[],
    N = 10
)



target_model = compile(model_def, data)
refer_model = compile(model_def_prior, data_prior)
targets = extract_distributions(target_model)
priors = extract_distributions(refer_model)

target = JuliaBUGSPotential(target_model, targets, priors)
reference = JuliaBUGSPotential(refer_model, priors, priors)
Pigeons.initialization(::JuliaBUGSPotential, ::AbstractRNG, ::Int) = prior_sampling_helper(priors)


pt = pigeons(
    target = target,
    reference = reference,
    explorer = JuliaBUGSGibbsSampler()
)
