@testset "LogSum" begin
    m = Pigeons.LogSum()

    fit!(m, 2.1)
    fit!(m, 4)
    v1 = value(m)
    @test v1 ≈ log(exp(2.1) + exp(4))

    fit!(m, 2.1)
    fit!(m, 4)
    m2 = Pigeons.LogSum()
    fit!(m2, 50.1)
    combined = merge(m, m2)
    @test value(combined) ≈ log(exp(v1) + exp(50.1))

    fit!(m, 2.1)
    fit!(m, 4)
    empty!(m)
    @test value(m) == -Pigeons.inf(0.0)
end