# For testing purpose, can be helpful to pass in Distributions.jl targets
# Note: inefficient, e.g. will compute useless normalization constants

(d::Distribution)(x) = logpdf(d, x) 

create_reference_log_potential(d::Distribution, ::Inputs) = 
    ScaledPrecisionNormalLogPotential(1.0, length(d))

create_state_initializer(d::Distribution, ::Inputs) = d
initialization(d::Distribution, ::SplittableRandom, ::Int) = zeros(length(d))

function bivariate_normal(std_dev_1, std_dev_2, rho) 
    @assert std_dev_1 > 0 
    @assert std_dev_2 > 0
    @assert -1 ≤ rho ≤ 1
    return MvNormal([
        std_dev_1^2                   rho * std_dev_1 * std_dev_2
        rho * std_dev_1 * std_dev_2   std_dev_2^2
    ])
end