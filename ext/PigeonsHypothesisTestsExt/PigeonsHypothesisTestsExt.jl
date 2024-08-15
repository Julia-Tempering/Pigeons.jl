module PigeonsHypothesisTestsExt

using Pigeons
if isdefined(Base, :get_extension)
    using DocStringExtensions
    using HypothesisTests: HypothesisTest, ApproximateTwoSampleKSTest, pvalue
    using SplittableRandoms: SplittableRandom
else
    using ..DocStringExtensions
    using ..HypothesisTests: HypothesisTest, ApproximateTwoSampleKSTest, pvalue
    using ..SplittableRandoms: SplittableRandom
end

"""
$SIGNATURES 

Implements [`Pigeons.invariance_test()`](@ref) for targets with states that can be
converted to `Vector{<:Real}`, using two-sample tests from `HypothesisTests.jl`.
"""
function Pigeons.invariance_test(
    target, 
    explorer, 
    rng::SplittableRandom,
    ::Type{two_sample_hypothesis_test} = ApproximateTwoSampleKSTest;
    n_iid_samples::Integer = 10_000,
    marginal_pvalue_threshold::Real = 0.005,
    simulator_kwargs...
    ) where {two_sample_hypothesis_test <: HypothesisTest}
    
    # allocate storage for the initial and final samples
    initial_values = Vector{Vector{typeof(marginal_pvalue_threshold)}}(undef, n_iid_samples)
    final_values = similar(initial_values)

    # iterate iid samples
    for n in eachindex(initial_values)
        initial_values[n] = Pigeons.forward_sample_condition_and_explore(
            target, explorer, rng; run_explorer=false, simulator_kwargs...)
        final_values[n] = Pigeons.forward_sample_condition_and_explore(
            target, explorer, rng; simulator_kwargs...)
    end

    # transform vector of vectors to matrices so that iterating dimensions == iterating columns => faster
    inits_mat = collect(hcat(initial_values...)')
    finals_mat = collect(hcat(final_values...)')
    @assert size(inits_mat) == size(finals_mat) "Initial values and final values have different dimensions"

    # use a Bonferroni correction for multiple testing
    corrected_pvalue_threshold = marginal_pvalue_threshold/size(finals_mat,2)

    # compute pvalues for all dimensions
    pvalues = map(zip(eachcol(inits_mat), eachcol(finals_mat))) do (x,y)
        pvalue(two_sample_hypothesis_test(x, y))
    end

    # inspect results
    failed_tests = findall(<(corrected_pvalue_threshold), pvalues)
    passed = length(failed_tests) == 0

    return (; passed, pvalues, failed_tests)
end


end # End module
