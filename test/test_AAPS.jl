using MCMCChains
if !is_windows_in_CI()
    @testset "AAPS" begin
        pt = pigeons(; 
            target = Pigeons.stan_banana(1, 1.0), 
            explorer = AAPS(step_size = 2. ^(-4)), 
            n_chains = 1, n_rounds = 12, record = [traces])
        @show minimum(ess(Chains(sample_array(pt))).nt.ess)
        @test true
    end
end
