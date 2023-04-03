using Pigeons

n_chains = 4
n_rounds = 5

pt = pigeons(; target = Pigeons.TestSwapper(1.0), recorder_builders = [Pigeons.round_trip], n_chains, n_rounds);