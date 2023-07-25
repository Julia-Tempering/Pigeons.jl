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
        (isa(e, DomainError) | isa(e, BoundsError)) ? -Inf : error("Unknown error in evaluation of the Turing log_potential.")
    end

"""
$SIGNATURES 
Given a `DynamicPPL.Model` from Turing.jl, create a 
`TuringLogPotential` conforming both [`target`](@ref) and 
[`log_potential`](@ref).
"""
@provides target TuringLogPotential(model::DynamicPPL.Model) = 
    TuringLogPotential(model, false)

function initialization(target::TuringLogPotential, rng::AbstractRNG, _::Int64)
    result = DynamicPPL.VarInfo(rng, target.model, DynamicPPL.SampleFromPrior(), DynamicPPL.PriorContext()) 
    DynamicPPL.link!!(result, DynamicPPL.SampleFromPrior(), target.model)
    return result 
end
initialization(target::TuringLogPotential) = initialization(target, SplittableRandom(1), 1)

# At the moment, AutoMALA assumes a :singleton_variable structure 
# so use the SliceSampler.
default_explorer(::TuringLogPotential) = SliceSampler()

default_reference(target::TuringLogPotential) = 
    TuringLogPotential(target.model, true)

function sample_iid!(log_potential::TuringLogPotential, replica, shared) 
    replica.state = initialization(log_potential, replica.rng, replica.replica_index)
end


LogDensityProblemsAD.dimension(log_potential::TuringLogPotential) = length(DynamicPPL.getall(initialization(log_potential)))
function LogDensityProblemsAD.ADgradient(kind::Symbol, log_potential::TuringLogPotential, buffers::Augmentation)
    @warn   """
            We recommend using SliceSampler() for Turing models. If you have a large continuous model 
            consider using the StanBridge. The Turing interface is still useful for models containing 
            both continuous and discrete variables. 
            
            Details:

            - The LogDensityProblems interface seems to force us to keep two representations of the states, 
              one for the VariableInfo and one vector based. This is only partly implemented at the moment, 
              as a result we have the following limitations: (1) AutoMALA+Turing cannot use the 
              diagonal pre-conditioning at the moment. (2) AutoMALA+Turing only works if all variables are 
              continuous at the moment. Both could be addressed but since the autodiff is pretty slow at the
              moment it seems low priority; the user can just rely on SliceSampler() at the moment. 
            - If the user has a fully continuous model, there is a good alternative: the Stan Bridge, 
              (which has much faster autodiff than Zygote, and Enzyme crashes on Turing at the time of writing). 
            - On some Turing models, gradient computation is non-deterministic, 
              see 4433584a044510bf9360e1e7191e59478496dc0b and associated CIs at 
              https://github.com/Julia-Tempering/Pigeons.jl/actions/runs/5550424683/jobs/10135522013
              vs 
              https://github.com/Julia-Tempering/Pigeons.jl/actions/runs/5550424683/jobs/10135521940
              (look for output of test_turing.jl)
            """ maxlog=1
    context = log_potential.only_prior ? DynamicPPL.PriorContext() : DynamicPPL.DefaultContext()
    fct = DynamicPPL.LogDensityFunction(initialization(log_potential), log_potential.model, context)
    return ADgradient(kind, fct)
end