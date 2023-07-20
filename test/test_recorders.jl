@testset "Default recorder groups" begin
    for target in [toy_mvn_target(10), toy_stan_target(10), Pigeons.toy_turing_target(10)]
        for record in [record_online(), record_default(), []]
            pigeons(; target, record)
        end
    end
end