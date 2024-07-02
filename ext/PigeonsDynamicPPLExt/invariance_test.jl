"""
$SIGNATURES 

Performs three operations using a `DynamicPPL.Model`. First, we run forward simulation
and record the output of the model. Currently we assume that a single object is observed
and returned whenever `model(rng)` is called.
Secondly, we condition the model using the sampled observation. Finally, we
take a step with `explorer` on the conditioned model starting from the values that
generated the observation. The function returns the unconstrained values of the 
initial and final states.
"""
function Pigeons.forward_sample_condition_and_explore(model::DynamicPPL.Model, explorer, rng::SplittableRandom)
    # forward simulation
    obs, vi = DynamicPPL.evaluate!!(model, rng)
    vns = DynamicPPL._getvns(vi, DynamicPPL.SampleFromPrior())

    # find the VarName of the generated observation
    # TODO: this is hacky since two variables might have the same sampled values.
    obs_var = first(vn for vn in vns if vi[vn] === obs)

    # condition the model using the sampled observation
    conditioned_model = DynamicPPL.condition(model, obs_var=>obs);
    cond_vi = last(DynamicPPL.evaluate!!(conditioned_model, rng))
    vns_cond = DynamicPPL._getvns(cond_vi, DynamicPPL.SampleFromPrior())

    # set the values of cond_vi to the ones that generated the observation
    foreach(vns_cond) do vn
        setindex!(cond_vi,vi[vn],vn) # note: vi[vn] is always in constrained space, even if vi is link!!'d
    end
    DynamicPPL.logjoint(conditioned_model, cond_vi) # recompute logjoint with new values

    # make a (concretely-)typed version of cond_vi, then transform it to unconstrained space 
    state = DynamicPPL.TypedVarInfo(cond_vi)
    DynamicPPL.link!!(state, DynamicPPL.SampleFromPrior(), conditioned_model)

    # record starting values and then take a step with explorer
    init_values = DynamicPPL.getall(state)
    final_state = Pigeons.explorer_step(rng, TuringLogPotential(conditioned_model), explorer, state)

    # return initial and final values
    return (;init_values=init_values, final_values=DynamicPPL.getall(final_state))
end

Pigeons.forward_sample_condition_and_explore(target::TuringLogPotential, args...) =
    Pigeons.forward_sample_condition_and_explore(target.model, args...)
