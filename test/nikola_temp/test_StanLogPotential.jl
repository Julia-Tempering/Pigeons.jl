using Pigeons
using BridgeStan
const BS = BridgeStan
using Random 
using SplittableRandoms

function main()
    # settings
    rng = SplittableRandom(1)
    bernoulli_stan = "test/nikola_temp/bernoulli.stan"
    bernoulli_data = "test/nikola_temp/bernoulli.data.json"
    bernoulli_data_prior = "test/nikola_temp/bernoulli_only_prior.data.json"

    # create Stan models
    smb = BS.StanModel(stan_file = bernoulli_stan, data = bernoulli_data)
    smb_prior = BS.StanModel(stan_file = bernoulli_stan, data = bernoulli_data_prior)
    x = rand(BS.param_unc_num(smb));
    q = @. log(x / (1 - x)); # unconstrained scale
    slp = StanLogPotential(smb, smb_prior, q)
    slp_prior = StanLogPotential(smb, smb_prior, true, q)

    # run Pigeons
    # pt = pigeons(target = slp)
    # nothing

    # test slicer 
    h = Pigeons.SliceSampler()
    n = 10
    states = Vector{typeof(q)}(undef, n)
    cached_lp = -Inf
    for i in 1:n
        cached_lp = Pigeons.slice_sample!(h, q, slp_prior, cached_lp, rng)
        states[i] = copy(q)
        # todo: transform to constrained (original) space
    end
    println(states)
end

main()