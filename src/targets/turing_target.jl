struct TuringLogPotential
    model::DynamicPPL.Model
    only_prior::Bool
end

function (log_potential::TuringLogPotential)(vi)
    # transform_back = false
    # if DynamicPPL.istrans(vi, DynamicPPL._getvns(vi, DynamicPPL.SampleFromPrior())[1]) # check if already transformed into unconstrained space
    #     DynamicPPL.invlink!!(vi, log_potential.model) # transform back to constrained space
    #     transform_back = true # transform it back after log_potential evaluation
    # end
    log_prior = DynamicPPL.logprior(log_potential.model, vi)
    if log_potential.only_prior
        out = log_prior
    else
        out = log_prior + loglikelihood(log_potential.model, vi)
    end
    # if transform_back 
    #     DynamicPPL.link!(vi, DynamicPPL.SampleFromPrior()) # transform to unconstrained space
    # end
    return out
end

"""
$SIGNATURES 
"""
@provides target TuringLogPotential(model::DynamicPPL.Model) = 
    TuringLogPotential(model, false)

create_state_initializer(target::TuringLogPotential, ::Inputs) = target  
initialization(target::TuringLogPotential, rng::SplittableRandom, _) = 
    DynamicPPL.VarInfo(rng, target, DynamicPPL.SampleFromPrior(), DynamicPPL.PriorContext()) 

create_explorer(target::TuringLogPotential, ::Inputs) = 
    SliceSampler()

create_reference_log_potential(target::TuringLogPotential, ::Inputs) = 
    TuringLogPotential(target.model, true)

function sample_iid!(log_potential::TuringLogPotential, replica) 
    replica.state = initialization(log_potential, replica.rng, replica.replica_index)
end