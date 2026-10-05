@static if !is_windows_in_CI()
    @testset "Allocs-Stan" begin
        #=
        Despite best effort, just can't get automala + stan bridge 
        all the way to zero allocs in the inner loop. See e.g. 
        9d85645b3422260043a59b89d049f54d782f76bc
        However what allocs are left are now dimension-independent. 
        This checks that a 100-fold increase in dim only increases allocs 
        by a small factor. 
        =#
        allocs_1d = Pigeons.last_round_max_allocation(pigeons(variational=GaussianReference(), n_chains=1, n_rounds=10, target=Pigeons.toy_stan_target(1), explorer=AutoMALA(exponent_n_refresh=0.0)))
        allocs_100d = Pigeons.last_round_max_allocation(pigeons(variational=GaussianReference(), n_chains=1, n_rounds=10, target=Pigeons.toy_stan_target(100), explorer=AutoMALA(exponent_n_refresh=0.0)))

        @test abs(allocs_1d - allocs_100d)/allocs_1d < 3
    end
end