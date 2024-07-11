using Distributions
using DynamicPPL
using FillArrays: Fill

@model function _GalaxyTuring(y, b_0, B_0)
    # hyperparams
    K   = 3
    α   = 1.0 # return to 0.01
    c_0 = 2.0
    C_0 = 1.0

    η  ~ Dirichlet(K, α)
    μ  ~ product_distribution(Fill(Normal(b_0, B_0), K))
    σ2 ~ product_distribution(Fill(InverseGamma(c_0, C_0), K))   
    y  ~ product_distribution(Fill(
        MixtureModel([Normal(μᵢ, sqrt(λᵢ)) for (μᵢ, λᵢ) in zip(μ, σ2)], η),
        length(y)
    ))
end

observed_range(x) = -(-(extrema(x)...))

function GalaxyTuring()
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
    b_0   = median(data)
    B_0   = observed_range(data)
    _GalaxyTuring(data, b_0, B_0)
end

pt = pigeons(
    target = TuringLogPotential(GalaxyTuring()),
    explorer = AutoMALA(),
    n_chains = 12, # Λ ~ 6
    n_rounds = 6   # low to speed up CI
)
