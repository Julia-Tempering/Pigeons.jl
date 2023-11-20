@testset "Moments" begin
    targets = Any[toy_mvn_target(2)]
    is_windows_in_CI() || push!(targets, toy_stan_target(2))
    for variational in [nothing, GaussianReference()]
        for target in targets
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
                    for i in 1:2  # not eachindex(v) as we skip :log_density
                        @test abs(m[i] - 0.0) < 0.03
                    end
                    v = var(pt, var_name)
                    for i in 1:2  # not eachindex(v) as we skip :log_density
                        @test abs(v[i] - 0.1) < 0.03
                    end
                end
            end
            
        end
    end
end