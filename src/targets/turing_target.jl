struct TuringLogPotential
    model::DynamicPPL.Model
    only_prior::Bool
end

function (log_potential::TuringLogPotential)(vi) 
    log_prior = logprior(log_potential.model, vi)
    return log_prior + log_potential.only_prior ? 
        zero(log_prior) :
        loglikelihood(log_potential.model, vi)
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
    replica.state = initialization(log_potential, replica.rng)
end