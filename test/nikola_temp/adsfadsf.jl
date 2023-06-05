using Pigeons 
using BridgeStan
const BS = BridgeStan

bernoulli_stan = "test/nikola_temp/bernoulli.stan"
bernoulli_data = "test/nikola_temp/bernoulli_prior.data.json"
smb = BS.StanModel(stan_file = bernoulli_stan, data = bernoulli_data)

x = [0.9]
q = @. log(x/(1-x))
println(q)
log_density(smb, q; propto = true, jacobian = true)

param_constrain!(smb, q, q)