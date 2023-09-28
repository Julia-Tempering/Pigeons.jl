#=
Extremely minimalistic test case. Essentially just checks that no error is thrown. 
For a more comprehensive set of tests see the AutoMALA tests, 
which also cover checks of the Hamiltonian dynamics.
=#
@testset "Basic MALA check" begin
    error_thrown = false 
    try 
        pt = pigeons(
            target = toy_mvn_target(10), 
            explorer = MALA(),
            n_chains = 1, 
            n_rounds = 10, 
            record = record_online(), 
            seed = 1
        )
    catch e 
        error_thrown = true 
    end 
    @test !error_thrown
end
