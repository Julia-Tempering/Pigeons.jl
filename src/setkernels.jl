using AdvancedHMC 
using ForwardDiff
using ReverseDiff
using Random
include("../src/hmc.jl") 

function setKernels(potential, Etas, L)
    kernels = Vector{SS}(undef, size(Etas)[1])
    for i in 1:size(Etas)[1]
        loglik = (x) -> potential(x, Etas[i, :]) # Negative of the log *density* (*not* the log-likelihood, despite what it says!)
        kernels[i] = SS(loglik) # Use slice sampling defaults
    end
    return kernels
end