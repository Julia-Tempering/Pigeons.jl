using Pigeons 

pt = pigeons(
    target = toy_mvn_target(10), 
    recorder_builders = [traces],
    n_chains = 10, 
    n_chains_var_reference = 10,
    var_reference = NoVarReference()
    )
s = get_sample(pt, 10)