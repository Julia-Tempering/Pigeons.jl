@testset "Extractors" begin 
    # Test the traces for Blang (recording only log_potential)
    pt = pigeons(
        target = Pigeons.blang_ising(2), 
        n_chains = 2,
        record = [traces; round_trip; record_default()])
    samples = Chains(pt)
    @test sample_names(pt) == [:log_density]
    Pigeons.kill_child_processes(pt)    
end