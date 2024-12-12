"""
$SIGNATURES 

Implements `Pigeons.forward_sample_condition_and_explore` for running invariance
tests using a [`JuliaBUGSPath`](@ref) as target.
"""
function Pigeons.forward_sample_condition_and_explore(
    model::JuliaBUGS.BUGSModel,
    rng::SplittableRandom;
    explorer = nothing,
    condition_on = ()
    )
    # sample and then store results in model evaluation_env
    new_env = _sample_iid(target.model, rng)
    model = JuliaBUGS.initialize!(model, new_env)

    # maybe condition the model using the sampled observations
    conditioned_model = if length(condition_on) > 0
        var_group = [JuliaBUGS.VarName{sym}() for sym in condition_on] # transform Symbols into VarNames
        JuliaBUGS.condition(model, var_group)
    else
        model
    end

    # maybe take a step with explorer
    state = JuliaBUGS.getparams(conditioned_model)
    return if !isnothing(explorer)
        Pigeons.explorer_step(rng, JuliaBUGSPath(conditioned_model), explorer, state)
    else
        state
    end
end

Pigeons.forward_sample_condition_and_explore(target::JuliaBUGSPath, args...; kwargs...) =
    Pigeons.forward_sample_condition_and_explore(target.model, args...; kwargs...)
    