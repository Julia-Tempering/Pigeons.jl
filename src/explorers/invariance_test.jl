"""
$SIGNATURES 

Run an invariance test of `explorer` on the provided `target`. Corresponds to a
modified Geweke test where the simulated data is kept fixed.

### References

Bouchard-Côté, A., Chern, K., Cubranic, D., Hosseini, S., Hume, J., Lepur, M., 
Ouyang, Z., & Sgarbi, G. (2022). [Blang: Bayesian Declarative Modeling of General 
Data Structures and Inference via Algorithms Based on Distribution Continua](https://doi.org/10.18637/jss.v103.i11). 
*Journal of Statistical Software, 103*(11), 1–98.

Geweke, J. (2004). [Getting It Right: Joint Distribution Tests of Posterior 
Simulators](https://doi.org/10.1198/016214504000001132). *Journal of the American Statistical Association, 99*(467),
799–804.
"""
function invariance_test end

"""
$SIGNATURES 

The workhorse under [`invariance_test`](@ref). It starts with a full forward pass
for the probabilistic model underlying `target`, thats simulates latent variables and
observations. Then a modified model is created that conditions the original model
on the observations produced. Finally, the function takes a step using the explorer
targetting the conditioned model. The function returns both pre- and post-exploration
states.
"""
function forward_sample_condition_and_explore end

"""
$SIGNATURES 

Utility for taking a single step of an `explorer` under a given `target` and
initial state `init_state`. Returns the modified state.

!!! note "Taking multiple steps"
    Note that taking more than a single step can be achieved in many Pigeons
    explorers by modifying their arguments for number of passes or refreshements. 
    For example, [`SliceSampler`](@ref) takes an `n_passes::Int` argument, while 
    [`AutoMALA`](@ref) takes the `base_n_refresh::Int` argument.
"""
function explorer_step(rng::SplittableRandom, target, explorer, init_state)
    inputs    = Inputs(target=target, explorer=explorer, n_chains=1)
    shared    = Pigeons.Shared(inputs)
    recorders = create_recorders(explorer_recorder_builders(explorer))
    replica   = Pigeons.Replica(init_state, 1, rng, recorders, 1)
    Pigeons.step!(explorer, replica, shared)
    return replica.state
end
