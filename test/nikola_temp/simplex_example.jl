using Pigeons 
using BridgeStan 
const BS = BridgeStan

bernoulli_stan = "test/nikola_temp/simplex.stan"
bernoulli_data = "test/nikola_temp/simplex_prior.data.json"

# PT settings
n_rounds = 10
n_chains = 10

# create Stan models
smb = BS.StanModel(stan_file = bernoulli_stan, data = bernoulli_data)