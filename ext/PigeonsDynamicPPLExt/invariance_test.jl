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
    condition_on::Union{Nothing,NTuple{<:Any,Symbol}} = nothing
    )
    # forward simulation
    vi = last(DynamicPPL.evaluate!!(model, rng))

    if isnothing(condition_on)
        cond_vi = vi
        conditioned_model = model
    else
        # make a generator of Pairs for each variable in `condition_on` and 
        # its sampled value
        obs_pairs = Iterators.map(condition_on) do sym 
            vn = DynamicPPL.VarName{sym}()
            vn => vi[vn]
        end

        # condition the model using the sampled observations, and evaluate it
        conditioned_model = DynamicPPL.condition(model, obs_pairs...)
        cond_vi = last(DynamicPPL.evaluate!!(conditioned_model, rng))
        vns_cond = keys(cond_vi)

        # set the values of cond_vi to the ones that generated the observations
        foreach(vns_cond) do vn
            # note: vi[vn] is always in constrained space, even if vi is linked
            setindex!(cond_vi,vi[vn],vn)
        end
        DynamicPPL.logjoint(conditioned_model, cond_vi) # recompute logjoint with new values
    end

    # make a (concretely-)typed version of cond_vi, then transform it to 
    # unconstrained space 
    state = DynamicPPL.TypedVarInfo(cond_vi) # no-op when cond_vi is typed
    state = DynamicPPL.link(state, conditioned_model)

    # maybe take a step with explorer
    if !isnothing(explorer)
        state = Pigeons.explorer_step(
            rng, TuringLogPotential(conditioned_model), explorer, state
        )
    end

    # return a flattened version of state
    return DynamicPPL.getindex_internal(state, Colon())
end

Pigeons.forward_sample_condition_and_explore(target::TuringLogPotential, args...; kwargs...) =
    Pigeons.forward_sample_condition_and_explore(target.model, args...; kwargs...)
