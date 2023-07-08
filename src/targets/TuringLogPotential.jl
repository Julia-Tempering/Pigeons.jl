@auto struct TuringLogPotential
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

default_explorer(::TuringLogPotential) = SliceSampler()

create_reference_log_potential(target::TuringLogPotential, ::Inputs) = 
    TuringLogPotential(target.model, true)

function sample_iid!(log_potential::TuringLogPotential, replica, shared) 
    replica.state = initialization(log_potential, replica.rng, replica.replica_index)
end

function dummy_vi(log_potential::TuringLogPotential) 
    # TODO: a bit hacky perhaps?
    dummy = initialization(log_potential, SplittableRandom(1), 1)
    dummy = DynamicPPL.link!!(dummy, DynamicPPL.SampleFromPrior(), turing_model(log_potential)) # transform to unconstrained space
    return dummy
end
LogDensityProblemsAD.dimension(log_potential::TuringLogPotential) = length(DynamicPPL.getall(dummy_vi(log_potential)))
function LogDensityProblemsAD.ADgradient(kind::Symbol, log_potential::TuringLogPotential, buffers::Augmentation)
    context = log_potential.only_prior ? DynamicPPL.PriorContext() : DynamicPPL.DefaultContext()
    fct = DynamicPPL.LogDensityFunction(dummy_vi(log_potential), log_potential.model, context)
    return ADgradient(kind, fct)
end