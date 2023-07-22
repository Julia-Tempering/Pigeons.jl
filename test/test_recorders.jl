@testset "Default recorder groups" begin
    for target in [toy_mvn_target(10), toy_stan_target(10), Pigeons.toy_turing_target(10)]
        for record in [record_online(), record_default(), []]
            pigeons(; target, record)
        end
    end
end

@testset "empty! online stats" begin
    using OnlineStats
    
    xs = randn((1_000,5))
    
    # scalars
    for T in [Mean, Variance]
        o = T()
        empty!(fit!(o, xs))
        @test o == T()
    end

    # matrices
    for T in [CovMatrix]
        o = T()
        empty!(fit!(o, xs |> eachrow))
        @test iszero(sum(abs2, value(o))) && iszero(nobs(o))
    end
end