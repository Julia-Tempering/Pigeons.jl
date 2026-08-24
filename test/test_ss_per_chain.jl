@testset "stepping_stone_per_chain matches analytic for MVN" begin
    # For two centered MVNs with kernel exp(-x'x / 2σ²), the log-ratio of 
    # normalizing constants along the geometric tempering path has a closed form:
    #   log(Z_β/Z_0) = -(d/2) [log(σ²_ref) + log(β/σ²_target + (1-β)/σ²_ref)]
    
    d = 5
    var_ref = 25.0
    var_target = 1.0
    
    struct LogMVNTarget
        var::Float64
    end
    (m::LogMVNTarget)(x::Vector{Float64}) = -(x' * x) / (2 * m.var)
    Pigeons.initialization(mvn::LogMVNTarget, rng::AbstractRNG, _::Int) = randn(rng, d)
    
    pt = pigeons(
        target = LogMVNTarget(var_target),
        reference = LogMVNTarget(var_ref),
        n_rounds = 10,
        n_chains = 30
    )
    
    result = stepping_stone_per_chain(pt)
    analytic = [
        -(d/2) * (log(var_ref) + log(β/var_target + (1-β)/var_ref))
        for β in result.betas
    ]
    
    # Sanity checks on structure
    @test length(result.betas) == length(result.log_norm_constants)
    @test result.betas[1] == 0.0
    @test result.betas[end] == 1.0
    @test result.log_norm_constants[1] == 0.0  # by construction
    
    for k in eachindex(result.betas)
        @test isapprox(result.log_norm_constants[k], analytic[k], atol=0.5)
    end
end