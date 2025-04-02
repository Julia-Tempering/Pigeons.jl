"""
$SIGNATURES 

Performs three operations using a `DynamicPPL.Model`. First, we run forward simulation
and record the output of the model, capturing the simulated values for every variable
in `condition_on`. Then, we condition the model using the sampled observations. Finally, we
take a step with `explorer` on the conditioned model starting from the values that
generated the observation. The function returns the unconstrained values of the 
initial and final states.
"""
function Pigeons.forward_sample_condition_and_explore(
    model::DynamicPPL.Model,
    rng::SplittableRandom;
    explorer = nothing,
    condition_on::NTuple{N,Symbol}
    ) where {N}
    # forward simulation
    vi = last(DynamicPPL.evaluate!!(model, rng))

    # make a generator of Pairs for each variable in `condition_on` and its sampled value
    obs_pairs = ((vn=DynamicPPL.VarName{sym}(); vn => vi[vn]) for sym in condition_on)

    # condition the model using the sampled observations, and evaluate it
    conditioned_model = DynamicPPL.condition(model, obs_pairs...)
    cond_vi = last(DynamicPPL.evaluate!!(conditioned_model, rng))
    vns_cond = DynamicPPL._getvns(cond_vi, DynamicPPL.SampleFromPrior())

    # set the values of cond_vi to the ones that generated the observations
    foreach(vns_cond) do vn
        setindex!(cond_vi,vi[vn],vn) # note: vi[vn] is always in constrained space, even if vi is link!!'d
    end
    DynamicPPL.logjoint(conditioned_model, cond_vi) # recompute logjoint with new values

    # make a (concretely-)typed version of cond_vi, then transform it to unconstrained space 
    state = DynamicPPL.TypedVarInfo(cond_vi)
    DynamicPPL.link!!(state, DynamicPPL.SampleFromPrior(), conditioned_model)

    # maybe take a step with explorer
    if !isnothing(explorer)
        state = Pigeons.explorer_step(rng, TuringLogPotential(conditioned_model), explorer, state)
    end

    # return a flattened version of state
    return DynamicPPL.getall(state)
end

Pigeons.forward_sample_condition_and_explore(target::TuringLogPotential, args...; kwargs...) =
    Pigeons.forward_sample_condition_and_explore(target.model, args...; kwargs...)
