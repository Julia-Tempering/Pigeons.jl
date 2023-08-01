using MCMCChains

@testset "DistributionLogPotential" begin
    @testset "Multivariate" begin
        function unid_log_potential(x; n_trials=100, n_successes=50)
            p1, p2 = x
            ((0 <= p1 <= 1) && (0 <= p2 <= 1)) || return typeof(p1)(-Inf)
            p = p1 * p2
            return n_successes*log(p) + (n_trials-n_successes)*log1p(-p)
        end
        ref_dist = product_distribution([Uniform(), Uniform()])
        pt = pigeons(
            target = unid_log_potential,
            reference = DistributionLogPotential(ref_dist),
            record = [traces]
        )
        @show Chains(sample_array(pt), variable_names(pt))
    end
    @testset "Univariate" begin
        pt = pigeons(
            target    = (x -> logpdf(Normal(3,1), x[begin])),
            reference = DistributionLogPotential(Normal(-3,1)),
            record    = [traces]
        )
        @show Chains(sample_array(pt), variable_names(pt))
    end
end
