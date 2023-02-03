using Pigeons

pt = pigeons(target = toy_mvn_target(2), recorder_builders = [Pigeons.target_online], n_rounds = 20);
for var_name in Pigeons.continuous_variables(pt)
    m = Pigeons.mean(pt, var_name)
    for i in eachindex(m)
        @test abs(m[i] - 0.0) < 0.001
    end
    v = Pigeons.variance(pt, var_name) 
    for i in eachindex(v) 
        @test abs(v[i] - 0.1) < 0.001 
    end
end