"""
Test to verify whether the initialization issue in JuliaBUGS 0.10 is due to:
1. evaluate_with_rng!! producing invalid samples, OR
2. Round-trip (env → getparams → evaluate_with_values!!) being broken

Run with: julia --project=test test/debug_initialization.jl
"""

include("supporting/setup.jl")
import JuliaBUGS
using JuliaBUGS: @bugs, compile

include("../examples/JuliaBUGS.jl")

# Use JuliaBUGS' native getparams for this test
getparams(model, env) = JuliaBUGS.Model.getparams(model, env)

println("="^80)
println("JuliaBUGS Initialization Round-Trip Test")
println("="^80)
println()

# Create the problematic model
model = incomplete_count_data_model(tau=0.01)
println("Model: incomplete_count_data(tau=0.01)")
println("  transformed: ", model.transformed)
println("  has generated function: ", !isnothing(model.log_density_computation_function))
println()

# Test the round-trip many times
n_trials = 1000
n_rng_invalid = 0
n_roundtrip_broken = 0
n_both_finite = 0

rng = Random.MersenneTwister(12345)

for i in 1:n_trials
    # Step 1: Sample from prior via evaluate_with_rng!!
    env, logdens = JuliaBUGS.Model.evaluate_with_rng!!(rng, model)

    logdens_finite = isfinite(logdens.logprior) && isfinite(logdens.loglikelihood) && isfinite(logdens.tempered_logjoint)

    # Step 2: Flatten using Pigeons' custom getparams
    x = getparams(model, env)

    # Step 3: Evaluate at the flattened parameters
    try
        env2, logdens2 = JuliaBUGS.Model.evaluate_with_values!!(
            model,
            x;
            temperature = 1.0,
            transformed = model.transformed,
        )

        logdens2_finite = isfinite(logdens2.logprior) && isfinite(logdens2.loglikelihood) && isfinite(logdens2.tempered_logjoint)

        if !logdens_finite
            global n_rng_invalid += 1
        elseif !logdens2_finite
            global n_roundtrip_broken += 1
            if i <= 3  # Print first few broken cases
                println("ROUND-TRIP BROKEN at trial $i:")
                println("  evaluate_with_rng!! → logdens: ", logdens)
                println("  evaluate_with_values!! → logdens2: ", logdens2)
                println("  State: ", x)
                println()
            end
        else
            global n_both_finite += 1
        end
    catch e
        if isa(e, DomainError) || isa(e, BoundsError)
            # evaluate_with_values!! threw an error
            if !logdens_finite
                global n_rng_invalid += 1
            else
                global n_roundtrip_broken += 1
                if i <= 3
                    println("ROUND-TRIP THREW EXCEPTION at trial $i:")
                    println("  evaluate_with_rng!! → logdens: ", logdens)
                    println("  evaluate_with_values!! → Exception: ", e)
                    println("  State: ", x)
                    println()
                end
            end
        else
            rethrow(e)
        end
    end
end

println("="^80)
println("RESULTS after $n_trials trials:")
println("="^80)
println("  Both finite:              $n_both_finite ($(round(100*n_both_finite/n_trials, digits=1))%)")
println("  evaluate_with_rng!! invalid:  $n_rng_invalid ($(round(100*n_rng_invalid/n_trials, digits=1))%)")
println("  Round-trip broken:        $n_roundtrip_broken ($(round(100*n_roundtrip_broken/n_trials, digits=1))%)")
println()

if n_roundtrip_broken > 0
    println("⚠️  DIAGNOSIS: Round-trip is BROKEN!")
    println("   evaluate_with_rng!! produces finite densities, but")
    println("   evaluate_with_values!! at the same parameters produces -Inf/errors.")
    println("   This suggests a bug in getparams or evaluate_with_values!! parameter layout.")
elseif n_rng_invalid > 0
    println("✓  Round-trip is OK.")
    println("   The -Inf states are coming directly from evaluate_with_rng!! sampling.")
    println("   The prior genuinely samples states with infinite log-likelihood.")
    println("   Retry logic is the correct fix.")
else
    println("✓  No issues found in $n_trials trials.")
    println("   The model might just rarely hit -Inf states.")
end
println("="^80)
