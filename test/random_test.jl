-# Toy example ----------
# using Pigeons

# inputs = Inputs(target = toy_mvn_target(100))
# pt = pigeons(inputs)


using Turing
using SplittableRandoms
using Pigeons

# Turing ----------


# *Unidentifiable* unconditioned coinflip model with `N` observations.
@model function coinflip_unidentifiable(; N::Int)
    p1 ~ Uniform(0, 1) # prior on p1
    p2 ~ Uniform(0, 1) # prior on p2
    y ~ filldist(Bernoulli(p1*p2), N) # data-generating model
    return y
end;
coinflip_unidentifiable(y::AbstractVector{<:Real}) = coinflip_unidentifiable(; N=length(y)) | (; y)

function flip_model_unidentifiable()
    p_true = 0.5; # true probability of heads is 0.5
    N = 100;
    data = rand(Bernoulli(p_true), N); # generate N data points
    return coinflip_unidentifiable(data)
end

using Pigeons
model = Pigeons.flip_model_unidentifiable()
inputs = Inputs(
    target = TuringLogPotential(model),
    n_chains = 0,
    n_chains_var_reference = 10,
    var_reference = Pigeons.GaussianReference()
)
pt = pigeons(inputs)



# rng = SplittableRandom(1)
# vi = DynamicPPL.VarInfo(rng, target.model, DynamicPPL.SampleFromPrior(), DynamicPPL.PriorContext()) 
# println("Hello world :)")




# pt = pigeons(target = toy_mvn_target(2), recorder_builders = [Pigeons.target_online], n_rounds = 20);
# for var_name in Pigeons.continuous_variables(pt)
#     m = Pigeons.mean(pt, var_name)
#     for i in eachindex(m)
#         @test abs(m[i] - 0.0) < 0.001
#     end
#     v = Pigeons.variance(pt, var_name) 
#     for i in eachindex(v) 
#         @test abs(v[i] - 0.1) < 0.001 
#     end
# end