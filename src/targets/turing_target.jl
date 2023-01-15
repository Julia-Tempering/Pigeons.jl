struct TuringLogPotential
    model::DynamicPPL.Model
    only_prior::Bool
end

(log_potential::TuringLogPotential)(vi) = 
    if log_potential.only_prior
        DynamicPPL.logprior(log_potential.model, vi)
    else  
        # Bug fix: avoiding now to break into prior and likelihood 
        #          calls, as it would add the log Jacobian twice.
        DynamicPPL.logjoint(log_potential.model, vi)
    end

"""
$SIGNATURES 
"""
@provides target TuringLogPotential(model::DynamicPPL.Model) = 
    TuringLogPotential(model, false)

create_state_initializer(target::TuringLogPotential, ::Inputs) = target  
initialization(target::TuringLogPotential, rng::SplittableRandom, _::Int64) = 
    DynamicPPL.VarInfo(rng, target.model, DynamicPPL.SampleFromPrior(), DynamicPPL.PriorContext()) 

create_explorer(target::TuringLogPotential, ::Inputs) = 
    SliceSampler()

create_reference_log_potential(target::TuringLogPotential, ::Inputs) = 
    TuringLogPotential(target.model, true)

function sample_iid!(log_potential::TuringLogPotential, replica) 
    replica.state = initialization(log_potential, replica.rng, replica.replica_index)
end