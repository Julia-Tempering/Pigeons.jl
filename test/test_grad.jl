include("supporting/HetPrecisionNormalLogPotential.jl")

@testset "Interpolated" begin 
    ref = Pigeons.ScaledPrecisionNormalLogPotential(2.0, 2)
    target = HetPrecisionNormalLogPotential([500.0, 1.0]) 
    inter = Pigeons.InterpolatedLogPotential(Pigeons.InterpolatingPath(ref, target), 0.2)

    ad = ADgradient(:ForwardDiff, inter, Pigeons.buffers()) 

    x = [1.1, 2.1]
    _, g1 = LogDensityProblems.logdensity_and_gradient(ad, x)

    g2 = ForwardDiff.gradient(inter, x)

    @test g1 ≈ g2
end