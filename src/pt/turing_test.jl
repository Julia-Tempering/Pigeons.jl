using Turing
using Random



# magic lines for Turing

# creating model:

p_true = 0.5;

N = 100;

data = rand(Bernoulli(p_true), N);

# Unconditioned coinflip model with `N` observations.
@model function coinflip(; N::Int)
    # Our prior belief about the probability of heads in a coin toss.
    p ~ Beta(1, 12)

    # Heads or tails of a coin are drawn from `N` independent and identically
    # distributed Bernoulli distributions with success rate `p`.
    y ~ filldist(Bernoulli(p), N)

    return y
end;

coinflip(y::AbstractVector{<:Real}) = coinflip(; N=length(y)) | (; y)

model = coinflip(data);


vi = DynamicPPL.VarInfo(rng, model, DynamicPPL.SampleFromPrior(), DynamicPPL.PriorContext()) 
println("sampled from prior: $(vi.metadata.p)") 

println("logprior: $(logprior(model, vi))")
println("loglikelihood: $(loglikelihood(model, vi))")

vi.metadata.p.vals[1] = 0.2

println("logprior: $(logprior(model, vi))")
println("loglikelihood: $(loglikelihood(model, vi))")

return



const DPPL = DynamicPPL

# TemperedModel built from a Turing model
struct TuringTemperedModel{Tm<:DPPL.Model,Ts<:DPPL.AbstractSampler,TVi<:DPPL.AbstractVarInfo} 
    model::Tm  # a DPPL.Model
    spl::Ts    # a DPPL.Sampler
    viout::TVi # a DPPL.VarInfo
end

# outer constructor
function TuringTemperedModel(model::DPPL.Model)
    viout = DPPL.VarInfo(model)            # build a TypedVarInfo
    spl   = DPPL.SampleFromPrior()         # used for sampling and to "link!" (transform to unrestricted space)
    TuringTemperedModel(model, spl, viout)
end

# copy a TuringTemperedModel. it keeps model.args common because that is the
# data, which can be huge
function Base.copy(tm::TuringTemperedModel)
    newmodel = tm.model.f(tm.model.args...)
    TuringTemperedModel(newmodel)
end



#######################################
# methods
#######################################

# sampling from the prior
function Base.rand(tm::TuringTemperedModel, rng::AbstractRNG)
    vi = DPPL.VarInfo(rng, tm.model, tm.spl, DPPL.PriorContext())         # one-liner of the following, after filling-in the missing context variable: https://github.com/TuringLang/DynamicPPL.jl/blob/715526ffa70292436e479e18d762e7ebf31c9181/src/sampler.jl#L86
    vi[tm.spl]
end
Random.rand!(tm::TuringTemperedModel, rng, x) = copyto!(x, rand(tm, rng)) # fallback since it is not possible to reuse x in a cleverer way

# evaluate reference potential + logabsdetjac of the bijection
function Vref(tm::TuringTemperedModel, x)
    -DPPL.getlogp(last(
        DPPL.evaluate_threadunsafe!!(                             # we copy vi when doing stuff in parallel so it's ok
            tm.model, DPPL.VarInfo(tm.viout, tm.spl, x), DPPL.PriorContext()
        )
    ))
end

# evaluate target potential
function V(tm::TuringTemperedModel, x)
    vi  = DPPL.VarInfo(tm.viout, tm.spl, x)
    pot = -DPPL.getlogp(last(
        DPPL.evaluate_threadunsafe!!(              # we copy vi when doing stuff in parallel so it's ok
            tm.model, vi, DPPL.LikelihoodContext()
        )
    ))
    return pot
end




loglikelihood(model, (p = 0.1,))

logprior(model, (p = 0.1,))


tm = TuringTemperedModel(model)


rng = MersenneTwister(1)

# @informal target begin
    
#     # log_potential for the log_density





# end



#=

A place where abstract types would be useful?

use scenarios:


- Turing user 
    - just pass in the Turing model 
        - can obtain prior_pots, likelihood_pots posterior_pots
        - can obtain prior sampler
        - dims to get variational approx 

    
- Low-level control 
    - explorer 
    - temperer 
    - reference 



=#