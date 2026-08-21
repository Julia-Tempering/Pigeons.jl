@testset "APIs" begin
    r = pigeons(target=toy_mvn_target(1), checkpoint=true, on=ChildProcess())
    # less often used APIs: specify the path (string) to a checkpoint
    pigeons(r.exec_folder)
    # ... and to run on child
    pigeons(r.exec_folder, ChildProcess())

    # test with no recorders 
    pigeons(target=toy_mvn_target(1), record=[])
end

@testset "Reports" begin
    pt = pigeons(target=toy_mvn_target(1))

    swaps_data = pt.shared.reports.swap_prs
    # @test size(swaps_data)[1] == 10 * 9
    @test size(swaps_data)[1] == 9 # delibrately mess up the test to see if CI jumps over the failed ones

    univ = pt.shared.reports.summary
    # @test size(univ)[1] == 10
    @test size(univ)[1] == 1 # delibrately mess up the test to see if CI jumps over the failed ones
end