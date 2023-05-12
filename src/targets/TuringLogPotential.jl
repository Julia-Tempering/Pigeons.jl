@concrete struct TuringLogPotential
    model
    only_prior::Bool
end

turing_model(log_potential::TuringLogPotential) = log_potential.model 
turing_model(log_potential::InterpolatedLogPotential) = log_potential.path.target.model

(log_potential::TuringLogPotential)(vi) = 
    try
        if log_potential.only_prior
            DynamicPPL.logprior(log_potential.model, vi)
        else  
            # Bug fix: avoiding now to break into prior and likelihood 
            #          calls, as it would add the log Jacobian twice.
            DynamicPPL.logjoint(log_potential.model, vi)
        end
    catch e
        isa(e, DomainError) ? -Inf : error("Unknown error in evaluation of the Turing log_potential.")
    end

"""
$SIGNATURES 
Given a `DynamicPPL.Model` from Turing.jl, create a 
`TuringLogPotential` conforming both [`target`](@ref) and 
[`log_potential`](@ref).
"""
@provides target TuringLogPotential(model::DynamicPPL.Model) = 
    TuringLogPotential(model, false)

create_state_initializer(target::TuringLogPotential, ::Inputs) = target  
initialization(target::TuringLogPotential, rng::SplittableRandom, _::Int64) = 
    DynamicPPL.VarInfo(rng, target.model, DynamicPPL.SampleFromPrior(), DynamicPPL.PriorContext()) 

create_explorer(::TuringLogPotential, ::Inputs) = SliceSampler()

create_reference_log_potential(target::TuringLogPotential, ::Inputs) = 
    TuringLogPotential(target.model, true)

function sample_iid!(log_potential::TuringLogPotential, replica, shared) 
    replica.state = initialization(log_potential, replica.rng, replica.replica_index)
end