@testset "Stan examples" begin
    pigeons(target = Pigeons.stan_eight_schools(true), n_rounds = 2, n_chains = 2)
    pigeons(target = Pigeons.stan_eight_schools(false), n_rounds = 2, n_chains = 2)
    pigeons(target = Pigeons.stan_banana(1), record = [online], n_chains = 1, n_rounds = 5, explorer = SliceSampler())

    # some examples where an error is interpreted as -Inf:
    pigeons(target = Pigeons.stan_funnel(1), record = [online], n_chains = 1, n_rounds = 5, explorer = SliceSampler())
end

@testset "Stan restarts" begin
    for explorer in [AutoMALA(), SliceSampler()]
        pt = pigeons(;
                target = Pigeons.stan_eight_schools(), 
                record = [round_trip], 
                variational = GaussianReference(), 
                explorer)
        n_restarts = n_tempered_restarts(pt)

        #=
        Incredible: 

            Different results on windows vs mac vs ubuntu CI
            seems consistent/reproducible within platform, with 
                mac: 111 round trips - see  https://github.com/Julia-Tempering/Pigeons.jl/actions/runs/5627237742/job/15249456691?pr=88
                win: 42              -      https://github.com/Julia-Tempering/Pigeons.jl/actions/runs/5627237742/job/15249456981?pr=88
                ubuntu: 107          -      https://github.com/Julia-Tempering/Pigeons.jl/actions/runs/5627237742/job/15249456839?pr=88
            Probably due to Stan's C++ toolchain/dependency version 
                differing across platforms..
        =#
        @test n_restarts > 40 # 100
    end
end