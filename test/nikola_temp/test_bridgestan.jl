using BridgeStan

const BS = BridgeStan

# BS.set_bridgestan_path!("../")

bernoulli_stan = joinpath(BS.get_bridgestan_path(), "test_models/bernoulli/bernoulli.stan")
bernoulli_data = joinpath(BS.get_bridgestan_path(), "../test_models/bernoulli/bernoulli.data.json")

smb = BS.StanModel(stan_file = bernoulli_stan, data = bernoulli_data)

# x = rand(BS.param_unc_num(smb));
# q = @. log(x / (1 - x)); # unconstrained scale

# lp, grad = BS.log_density_gradient(smb, q, jacobian = false)

# println("log_density and gradient of Bernoulli model: $((lp, grad))")