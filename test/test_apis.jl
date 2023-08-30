@testset "APIs" begin
    r = pigeons(target = toy_mvn_target(1), checkpoint = true, on = ChildProcess())
    # less often used API: specify the path (string) to a checkpoint
    pigeons(r.exec_folder)

    # test with no recorders 
    pigeons(target = toy_mvn_target(1), record = [])
end

@testset "Reports" begin 
    pt = pigeons(target = toy_mvn_target(1))

    swaps_data = pt.shared.reports.swap_prs
    @test size(swaps_data)[1] == 10 * 9

    univ = pt.shared.reports.summary
    @test size(univ)[1] == 10
end