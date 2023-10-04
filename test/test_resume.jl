@testset "Extend number of rounds with source_exec_folder" begin
    r = pigeons(; target = toy_mvn_target(1), checkpoint = true, on = ChildProcess())
    new_exec = increment_n_rounds!(r.exec_folder, 2)
    pt = pigeons(new_exec)
    @test pt.inputs.n_rounds == 12
    Pigeons.check_against_serial(pt)
end

@testset "Extend number of rounds with PT object" begin
    for checkpoint in [true, false]
        pt = pigeons(; target = toy_mvn_target(1))
        pt = increment_n_rounds!(pt, 2)
        pt = pigeons(pt)
        @test pt.inputs.n_rounds == 12
    end
end

@testset "Extend number of rounds with PT object, on ChildProcess" begin
    pt = pigeons(; target = toy_mvn_target(1), checkpoint = true)
    pt = increment_n_rounds!(pt, 2)
    r = pigeons(pt.exec_folder, ChildProcess(n_local_mpi_processes = 2))
    Pigeons.check_against_serial(load(r))
end

@testset "Complex example of increasing number of rounds many times" begin
    pt = pigeons(target = toy_mvn_target(1), checkpoint = true) 
    @test pt.shared.iterators.round == 10
    pt = increment_n_rounds!(pt, 1) 
    pigeons(pt)
    @test pt.shared.iterators.round == 11
    pt = PT("results/latest")
    pt = increment_n_rounds!(pt, 2) 
    pt = pigeons(pt)
    @test pt.shared.iterators.round == 13
    Pigeons.check_against_serial(pt)
end

@testset "Complex example from doc" begin
    pigeons(target = toy_mvn_target(100), n_rounds = 13)

    pt = pigeons(target = toy_mvn_target(100), checkpoint = true)

    println(pt.exec_folder)
    # # do two more rounds of sampling
    pt = increment_n_rounds!(pt, 2)
    pt = pigeons(pt)

    pt = increment_n_rounds!(pt, 1)
    result = pigeons(pt.exec_folder, ChildProcess(n_local_mpi_processes = 2)) 

    new_exec_folder = increment_n_rounds!(result.exec_folder, 1)
    result = pigeons(new_exec_folder, ChildProcess(n_local_mpi_processes = 2))

    # make sure it is equivalent to doing it in one shot
    Pigeons.check_against_serial(load(result))
end
