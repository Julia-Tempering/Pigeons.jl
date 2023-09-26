using Pigeons 

pt = pigeons(
    target = toy_mvn_target(10), 
    explorer = AAPS(), 
    n_chains = 1, 
    n_rounds = 4, 
    record = [traces]
)

samples = get_sample(pt)