module ParallelTempering 
using Base: Forward
using LinearAlgebra
using Distributions
using Statistics
using StatsBase
using Dierckx
using ForwardDiff
using Plots
using GLMakie
using CairoMakie
using Interpolations
using RCall
using TimerOutputs
@rlibrary mcmcse
using StatsPlots
using Roots
using Dates
using JLD2
using CSV
using DataFrames

export nrpt, sampleNUTS, DEO, computeEtas, roundtrip, plot_samples, summarize_samples, plot_roundtrip, plot_globalbarrier, 
plot_trace, plot_localbarrier, plot_ESS, get_chain_states, plot_sumroundtrip, run_all_PT_methods, run_simulation, 
store_simulation_results, make_all_plots, logsumexp!, plot_Blang_globalbarrier, plot_Blang_localbarrier, MSC_train, 
reverseKL_train, plot_MSC_KL_train, logpdf_LogUniform, rand_LogUniform, plot_sumroundtrip_time, restarts


### Samplers
include("explorationkernels.jl")
include("hmc.jl")
include("slice_sampling.jl")


### NRPT
include("etas.jl")
include("acceptance.jl")
include("communicationbarrier.jl")
include("updateschedule.jl")
include("roundtriprate.jl")
include("lognormalizingconstant.jl")
include("deoscan.jl")
include("deo.jl")
include("nrpt.jl")


### Useful tools
include("summarize_samples.jl")
include("get_chain_states.jl")
include("Winsorized_mean.jl")
include("Winsorized_std.jl")
include("logsumexp.jl")
include("loguniform.jl")

end