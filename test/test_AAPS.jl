
@testset "AAPS" begin
    pt = pigeons(; 
            target = toy_mvn_target(2), 
            n_chains = 2, 
            explorer = AAPS(),
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
