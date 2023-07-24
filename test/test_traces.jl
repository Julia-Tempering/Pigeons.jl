using MCMCChains

@testset "Sample matrix" begin

    for use_two_chains in [true, false]
        targets = [
            Pigeons.toy_stan_target(3), 
            Pigeons.toy_turing_target(3)
        ]
        if !use_two_chains 
            push!(targets, toy_mvn_target(3))
        end

        for target in targets
            
            pt = pigeons(; 
                    target, 
                    record = [traces],
                    n_rounds = 2, 
                    n_chains_variational  = use_two_chains ? 10 : 0,
                    variational = use_two_chains ? GaussianReference() : nothing
                )

            mtx = sample_array(pt) 
            @test size(mtx) == (4, 3, use_two_chains ? 2 : 1)
            @test length(variable_names(pt)) == 3
            chain = Chains(sample_array(pt), variable_names(pt))
        end 
    end

end

@testset "Traces" begin
    for target in [toy_mvn_target(10), toy_stan_target(10), Pigeons.toy_turing_target(10)]
        r = pigeons(; 
                target, 
                record = [traces, disk, online], 
                multithreaded = false,  # setting to true puts too much pressure on CI instances? https://github.com/Julia-Tempering/Pigeons.jl/actions/runs/5627897144/job/15251121621?pr=90
                checkpoint = true, 
                on = ChildProcess(n_local_mpi_processes = 2, n_threads = 1)) # setting to more than 1 puts too much pressure on CI instances? 
        pt = load(r)        
        @test length(pt.reduced_recorders.traces) == 1024
        marginal = [get_sample(pt, 10, i)[1] for i in 1:1024]
        s = get_sample(pt, 10)
        @test marginal == first.(s)
        @test abs(mean(marginal) - 0.0) < 0.05
        @test isapprox(mean(marginal), mean(pt)[1], atol = 1e-10)
        @test mean(marginal) ≈ mean(s)[1]
        @test s[1] == get_sample(pt, 10, 1)
        @test size(s)[1] == length(marginal)
        @test_throws "You cannot" setindex!(s, s[2], 1)
        # check that the disk serialization gives the same result
        process_sample(pt) do chain, scan, sample
            @test sample == get_sample(pt, chain, scan)
        end
    end
end

