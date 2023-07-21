include("supporting/lazy.jl")

@testset "LazyTarget" begin
    pigeons(target = Pigeons.LazyTarget(MyTargetFlag()))
    r = pigeons(target = Pigeons.LazyTarget(MyTargetFlag()), 
                    checkpoint = true,
                    on = ChildProcess(
                            n_local_mpi_processes = 2, 
                            n_threads = 2,
                            dependencies = ["$(@__DIR__)/supporting/lazy.jl"]
                    ))
    pt1 = load(r)
    pt2 = pigeons(target = toy_mvn_target(1))

    @test pt1.replicas == pt2.replicas
end