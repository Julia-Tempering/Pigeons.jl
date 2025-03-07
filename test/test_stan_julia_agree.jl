
include("supporting/funnel.jl")

if !is_windows_in_CI()

    @testset "Agreement Stan and Julia" begin 
        some_ref = NealFunnel(2, 1.0)
        targets = [NealFunnel(2, 2.0), Pigeons.stan_funnel(2, 2.0)] 
        for explorer in [SliceSampler(), AutoMALA()]
            pts = map(targets) do target 
                pigeons(; target, explorer, record = [traces], n_chains = 1, reference = some_ref)
            end
            @test sample_array(pts[1]) ≈ sample_array(pts[2])
        end
    end


end
