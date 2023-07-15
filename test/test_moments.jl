@testset "Moments" begin
    for var_reference in [NoVarReference(), GaussianReference()]
        for target in [toy_mvn_target(2), toy_stan_target(2)]
            if !(var_reference isa GaussianReference) || !(target isa Pigeons.ScaledPrecisionNormalPath)
                pt = pigeons(; 
                        target, 
                        n_chains = 2, 
                        var_reference,
                        recorder_builders = [Pigeons.online], 
                        n_rounds = 10);
                for var_name in Pigeons.continuous_variables(pt)
                    m = mean(pt, var_name)
                    for i in eachindex(m)
                        @test abs(m[i] - 0.0) < 0.02
                    end
                    v = var(pt, var_name)
                    for i in eachindex(v)
                        @test abs(v[i] - 0.1) < 0.02
                    end
                end
            end
        end
    end
end