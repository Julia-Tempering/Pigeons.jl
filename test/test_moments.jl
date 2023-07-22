@testset "Moments" begin
    for variational in [nothing, GaussianReference()]
        for target in [toy_mvn_target(2), toy_stan_target(2)]
            @show variational, target
            if !(variational isa GaussianReference) || !(target isa Pigeons.ScaledPrecisionNormalPath)
                pt = pigeons(; 
                        target, 
                        n_chains = 2, 
                        variational,
                        record = [Pigeons.online], 
                        n_rounds = 10);
                for var_name in Pigeons.continuous_variables(pt)
                    m = mean(pt, var_name)
                    for i in eachindex(m)
                        @test abs(m[i] - 0.0) < 0.03
                    end
                    v = var(pt, var_name)
                    for i in eachindex(v)
                        @test abs(v[i] - 0.1) < 0.03
                    end
                end
            end
        end
    end
end