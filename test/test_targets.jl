include("supporting/HetPrecisionNormalLogPotential.jl")

@testset "Interpolated" begin 
    ref = Pigeons.ScaledPrecisionNormalLogPotential(2.0, 2)
    target = HetPrecisionNormalLogPotential([500.0, 1.0]) 
    inter = Pigeons.InterpolatedLogPotential(Pigeons.InterpolatingPath(ref, target), 0.2)
    @test_throws ErrorException Pigeons.sample_iid!(inter, nothing, nothing)
end