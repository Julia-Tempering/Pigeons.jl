using Pigeons 
using BridgeStan
const BS = BridgeStan
using Plots

function main()
    # settings
    stan = "test/nikola_temp/eight_schools_noncentered.stan"
    data = "test/nikola_temp/eight_schools.json"

    # PT settings
    n_rounds = 3
    n_chains = 10

    # create Stan models
    smb = BS.StanModel(stan_file = stan, data = data)
    slp = StanLogPotential(smb)

    # run Pigeons
    pt = pigeons(
        target = slp, n_rounds = n_rounds, n_chains = 0, # set to 0 for now until bug is fixed
        recorder_builders = [traces], n_chains_var_reference = n_chains, 
        var_reference = GaussianReference())
    s = get_sample(pt, n_chains)
    samples_vec = map((x) -> x[1], s) # get first element
    p = Plots.histogram(samples_vec, bins = -3:0.1:3)
    display(p)
end

main()
