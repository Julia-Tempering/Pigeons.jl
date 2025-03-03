
function remove_repo(repo_name)
    auto_install_folder = mkpath(Pigeons.mpi_settings_folder())
    repo_path = "$auto_install_folder/$repo_name"
    rm(repo_path, force = true, recursive=true)
end

@testset "Setup blang" begin

    # 14/7/23 - found and fixed a bug (upstream in Blang SDK)
    
    # These are using pre-compiled zips
    Pigeons.setup_blang("blangDemos")
    Pigeons.setup_blang("nowellpack")

    try
        # For code coverage only, test the compilation route on some gradle project
        Pigeons.setup_blang("inits")
    catch 
    end
            
    for target in [
            Pigeons.blang_ising(), 
            Pigeons.blang_unid(), 
            Pigeons.blang_sitka()]
        pt = pigeons(; target, n_rounds = 2, n_chains = 2)
        Pigeons.kill_child_processes(pt)
    end
end

@testset "Blang restarts" begin

    # 2023/07/17: fixed bug upstream in Bayonet -> blangSDK -> blangDemos
    # 2023/07/17, continued: fixed another bug upstream in BlangSDK

    pt = pigeons(;
            target = Pigeons.blang_eight_schools(), 
            record = [round_trip], n_chains = 2)
    # NB: 10 chains runs out of memory in CI... reducing number of chains
    n_restarts = n_tempered_restarts(pt)
    global_barrier = Pigeons.global_barrier(pt.shared.tempering)
    @test n_restarts == 176
    @test global_barrier == 0.6610060719271351
end