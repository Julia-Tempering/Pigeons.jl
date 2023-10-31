#=
Extremely minimalistic test case.
For a more comprehensive set of tests see the AutoMALA tests, 
which also cover checks of the Hamiltonian dynamics.
=#
@testset "MALA" begin
    pt = pigeons(; 
            target = toy_mvn_target(2), 
            n_chains = 2, 
            explorer = MALA(),
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
