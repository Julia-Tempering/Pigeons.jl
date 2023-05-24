using Pigeons
using BridgeStan
const BS = BridgeStan
using Random 
using SplittableRandoms
using Plots

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
    n = 100_000
    states = Vector{typeof(q)}(undef, n)
    states_transf = copy(states)
    cached_lp = -Inf
    for i in 1:n
        cached_lp = Pigeons.slice_sample!(h, q, slp_prior, cached_lp, rng)
        states[i] = copy(q)
        states_transf[i] = param_constrain(smb_prior, states[i])
    end
    # println(states_transf)
    states_transf_vec = map((x) -> x[1], states_transf)
    p = histogram(states_transf_vec)
    display(p)
end

main()