struct OnlyFirstExtractor end 

Pigeons.extract_sample(state, log_potential, extractor::OnlyFirstExtractor) = 
    Pigeons.extract_sample(state, log_potential)[1:1]

@testset "Custom extractor" begin 
    target = Pigeons.toy_turing_unid_target(100, 50)

    pt = pigeons(;  target, 
                n_rounds = 3,
                # custom method to extract samples:
                extractor = OnlyFirstExtractor(),
                # make sure to record the trace:
                record = [traces; round_trip; record_default()])

    s = last(get_sample(pt)) 
    @test length(s) == 1
end

@testset "Blang extractors" begin 
    # Test the traces for Blang (recording only log_potential)
    pt = pigeons(
        target = Pigeons.blang_ising(2), 
        n_chains = 2,
        record = [traces; round_trip; record_default()])
    samples = Chains(pt)
    @test sample_names(pt) == [:log_density]
    Pigeons.kill_child_processes(pt)    
end