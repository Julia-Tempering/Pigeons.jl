
function remove_repo(repo_name)
    auto_install_folder = mkpath(Pigeons.mpi_settings_folder())
    repo_path = "$auto_install_folder/$repo_name"
    rm(repo_path, force = true, recursive=true)
end

@testset "Setup blang" begin

    # 14/7/23 - found and fixed a bug (upstream in Blang SDK)
    
    # The gradle task sometimes fails in CI 
    # when it tries to access the network, e.g. 
    #   https://github.com/Julia-Tempering/Pigeons.jl/actions/runs/5557665969/jobs/10151752331
    #   [look for java.net.SocketException: Broken pipe (Write failed)]
    # probably some throttling related issue?
    # As a work-around, retry up to 10 times 
    # (when it is already installed, setup_blang() does nothing)
    success = false
    for i in 1:10 
        try
            Pigeons.setup_blang("blangDemos")
            Pigeons.setup_blang("nowellpack")
            success = true
        catch e 
            @error "Something went wrong" exception=(e, catch_backtrace())
            remove_repo("blangDemos")
            remove_repo("nowellpack")
        end
    end
    if !success 
        error("Unable to setup blang")
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
    @test n_restarts > 180
    @test abs(global_barrier - 0.7) < 0.1
end