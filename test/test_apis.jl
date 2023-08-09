@testset "APIs" begin
    r = pigeons(target = toy_mvn_target(1), checkpoint = true, on = ChildProcess())
    # less often used API: specify the path (string) to a checkpoint
    pigeons(r.exec_folder)
end