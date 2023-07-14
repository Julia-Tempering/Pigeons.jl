@testset "Traces" begin
    for target in [toy_mvn_target(10), toy_stan_target(10), Pigeons.toy_turing_target(10)]
        r = pigeons(; 
                target, 
                recorder_builders = [traces, disk, online], 
                checkpoint = true, 
                on = ChildProcess(n_local_mpi_processes = 2, n_threads = 2))
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
        process_samples(pt) do chain, scan, sample
            @test sample == get_sample(pt, chain, scan)
        end
    end
end