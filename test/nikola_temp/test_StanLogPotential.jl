using Pigeons
using BridgeStan
const BS = BridgeStan
using Random 
using SplittableRandoms
using Plots

# function main()
    # settings
    bernoulli_stan = "test/nikola_temp/bernoulli.stan"
    bernoulli_data = "test/nikola_temp/bernoulli.data.json"
    bernoulli_data_prior = "test/nikola_temp/bernoulli_only_prior.data.json"

    # PT settings
    n_rounds = 10
    n_chains = 10

    # create Stan models
    smb = BS.StanModel(stan_file = bernoulli_stan, data = bernoulli_data)
    smb_prior = BS.StanModel(stan_file = bernoulli_stan, data = bernoulli_data_prior)
    x = rand(BS.param_unc_num(smb)) # constrained scale
    slp = StanLogPotential(smb, smb_prior, x)
    slp_prior = StanLogPotential(smb, smb_prior, true, x)

    # run Pigeons
    pt = pigeons(
        target = slp_prior, n_rounds = n_rounds, n_chains = n_chains, 
        recorder_builders = [traces])
    s = get_sample(pt, n_chains)
    samples_vec = map((x) -> x[1], s)
    p = Plots.histogram(samples_vec, bins = -3:0.1:3)
    display(p)
    nothing
# end

# main()


# q = @. log(x/(1-x)) # unconstrained
# param_unc_num(smb) # 1
# param_num(smb) # 1
# param_constrain(smb, q) # return constrained vector of parameters
