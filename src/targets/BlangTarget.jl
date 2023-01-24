""" 
A [`StreamTarget`](@ref) delegating exploration to 
[Blang worker processes](https://www.stat.ubc.ca/~bouchard/blang/).

Limitation: this should be called on a pre-compiled blang model, 
i.e. via `java package.MyBlangModel ...`, rather than via 
`blang ...` since the latter could cause several MPI processes to 
simultaneously attempt to compile in the same directory. 
"""
struct BlangTarget <: StreamTarget
    command::Cmd
end

initialization(target::BlangTarget, rng::SplittableRandom, replica_index::Int64) = 
    StreamState(
        `$(target.command) 
            --experimentConfigs.resultsHTMLPage false
            --experimentConfigs.saveStandardStreams false
            --engine blang.engines.internals.factories.Pigeons 
            --engine.random $(java_seed(rng))`,
        replica_index)

blang_sitka(model_options) = 
    BlangTarget(`$(blang_executable("nowellpack", "corrupt.NoisyBinaryModel")) $model_options`)
    
blang_sitka() = blang_sitka(`
        --model.binaryMatrix $(blang_repo_path("nowellpack"))/examples/535/filtered.csv 
        --model.globalParameterization true 
        --model.fprBound 0.005 
        --model.fnrBound 0.5 
        --model.minBound 0.001  
        --model.samplerOptions.useCellReallocationMove true  
        --model.predictivesProportion 0.0  
        --model.samplerOptions.useMiniMoves true
    `)

blang_ising() = blang_ising(`--model.N 10`)

blang_ising(model_options) = 
    BlangTarget(
        `$(blang_executable("blangDemos", "blang.validation.internals.fixtures.Ising")) $model_options`
    )
    
blang_repo_path(repo_name) = 
    "$(mkpath(mpi_settings_folder()))/$repo_name"

function blang_executable(repo_name, qualified_main_class)
    repo_path = blang_repo_path(repo_name)
    if !isdir(repo_path)
        error("run Pigeons.setup_blang(\"$repo_name\") first")
    end
    libs = "$repo_path/build/install/$repo_name/lib/"
    return `java -cp $libs/\* $qualified_main_class`
end

function setup_blang(
        repo_name, 
        organization = "UBC-Stat-ML")

    auto_install_folder = mkpath(mpi_settings_folder())
    repo_path = "$auto_install_folder/$repo_name"
    if isdir(repo_path)
        error("it seems setup() was alrady ran for $repo_name; to rerun the setup for $repo_name, first remove the folder $repo_path")
    end

    cd(auto_install_folder) do
        run(`git clone git@github.com:$organization/$repo_name.git`)
    end 

    cd(repo_path) do
        run(`$repo_path/gradlew installDist`)
    end 
end