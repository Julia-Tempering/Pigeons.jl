using BridgeStan

const BS = BridgeStan

bernoulli_stan = "test/nikola_temp/bernoulli.stan"
bernoulli_data = "test/nikola_temp/bernoulli.data.json"
# bernoulli_data = "test/nikola_temp/bernoulli_only_prior.data.json"

smb = BS.StanModel(stan_file = bernoulli_stan, data = bernoulli_data);

println("This model's name is $(BS.name(smb)).")
println("It has $(BS.param_num(smb)) parameters.")

x = rand(BS.param_unc_num(smb));
q = @. log(x / (1 - x)); # unconstrained scale

lp = BS.log_density(smb, q; propto = true, jacobian = false)

println("log_density of Bernoulli model: $lp")