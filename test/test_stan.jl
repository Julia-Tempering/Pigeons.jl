if !is_windows_in_CI()

    include("supporting/postdb.jl")

    @testset "Stan generated quantity" begin 
        # an example from posterior db with generated quantities and transformed parameters
        setup_posterior_db()
        posterior_json_file = "bball_drive_event_1-hmm_drive_1.json"
        pt = pigeons(; 
                        record = [traces; record_default()],
                        target = log_potential_from_posterior_db(posterior_json_file), n_rounds = 2)
        # make sure transformed and generated quantities included:
        @test length(sample_names(pt)) == 429 + 1 # +1 for log_density
    end

    @testset "Stan examples" begin
        pigeons(target = Pigeons.stan_eight_schools(true), n_rounds = 2, n_chains = 2)
        pigeons(target = Pigeons.stan_eight_schools(false), n_rounds = 2, n_chains = 2)
        pigeons(target = Pigeons.stan_banana(1, 1.0), record = [online], n_chains = 1, n_rounds = 5, explorer = SliceSampler())

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

    @testset "Stan custom sampler" begin 
        stan_file = dirname(dirname(pathof(Pigeons))) * "/examples/stan/unid.stan"
        stan_data = Pigeons.json(; n_trials = 1, n_successes = 1)
        dummy_extra_info = 123
        target = StanLogPotential(stan_file, stan_data, dummy_extra_info)
        result = pigeons(; target, n_chains = 1, checkpoint = true, n_rounds = 1, on = ChildProcess(dependencies = [BridgeStan]))
        pt = Pigeons.load(result)
        @assert pt.inputs.target.extra_information == dummy_extra_info
    end

end
