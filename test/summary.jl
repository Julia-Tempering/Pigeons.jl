@testset "summary.jl" begin
    means = [1.0, 2.0, 3.0, 4.0, 5.0]
    vars = [1.1, 2.2, 3.3, 4.4, 5.5]
    s = Pigeons.Summary(means, vars, 5)
    Pigeons.print(s)
end