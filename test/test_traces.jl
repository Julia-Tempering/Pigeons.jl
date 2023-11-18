using MCMCChains
using DynamicPPL
using BridgeStan
using DynamicPPL
using BridgeStan

@testset "Sample matrix" begin
    for extended_traces in [true, false]
        for use_two_chains in [true, false]
            targets = Any[Pigeons.toy_turing_target(3)]
            use_two_chains || push!(targets, toy_mvn_target(3))
            is_windows_in_CI() || push!(targets, Pigeons.toy_stan_target(3))

            for target in targets
                pt = pigeons(;
                        target,
                        extended_traces,
                        record = [traces],
                        n_rounds = 2,
                        n_chains_variational  = use_two_chains ? 10 : 0,
                        variational = use_two_chains ? GaussianReference() : nothing
                    )

                mtx = sample_array(pt)
                @test size(mtx) == (4, 3 + 1, (use_two_chains ? 2 : 1) * (extended_traces ? 10 : 1))
                @test length(variable_names(pt)) == 4
                @test :log_density in variable_names(pt)
                chain = Chains(pt)
                params, internals = MCMCChains.get_sections(chain) 

                @test length(keys(params)) == 3 
                @test length(keys(internals)) == 1 
                @test :log_density in keys(internals) 
            end
        end
    end
end

@testset "Traces" begin
    targets = Any[toy_mvn_target(10), Pigeons.toy_turing_target(10)]
    is_windows_in_CI() || push!(targets, toy_stan_target(10))
    for extended_traces in [true, false]
        for target in targets
            r = pigeons(;
                    target,
                    record = [traces, disk, online],
                    extended_traces,
                    multithreaded = false,  # setting to true puts too much pressure on CI instances? https://github.com/Julia-Tempering/Pigeons.jl/actions/runs/5627897144/job/15251121621?pr=90
                    checkpoint = true,
                    on = ChildProcess(n_local_mpi_processes = 2, n_threads = 1, dependencies=[DynamicPPL, BridgeStan])) # setting to more than 1 puts too much pressure on CI instances?
            pt = load(r)
            @test length(pt.reduced_recorders.traces) == 1024 * (extended_traces ? 10 : 1)
            for chain in Pigeons.chains_with_samples(pt)
                marginal = [get_sample(pt, chain, i)[1] for i in 1:1024]
                s = get_sample(pt, chain)
                @test marginal == first.(s)
                @test abs(mean(marginal) - 0.0) < 0.1
                if !extended_traces
                    @test isapprox(mean(marginal), mean(pt)[1], atol = 1e-10)
                end
                @test mean(marginal) ≈ mean(s)[1]
                @test s[1] == get_sample(pt, chain, 1)
                @test size(s)[1] == length(marginal)
                @test_throws "You cannot" setindex!(s, s[2], 1)
                # check that the disk serialization gives the same result
                process_sample(pt) do chain, scan, sample
                    @test sample == get_sample(pt, chain, scan)
                end
            end
        end
    end
end
