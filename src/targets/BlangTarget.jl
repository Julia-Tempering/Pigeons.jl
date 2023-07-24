""" 
A [`StreamTarget`](@ref) delegating exploration to 
[Blang worker processes](https://www.stat.ubc.ca/~bouchard/blang/).

```@example Blang_Pigeons
using Pigeons

Pigeons.setup_blang("blangDemos", "UBC-Stat-ML") # pre-compile the blang models in the github repo UBC-Stat-ML/blangDemos
pigeons(target = Pigeons.blang_ising());
```

Type `Pigeons.blang` followed by tab to find other examples. 
"""
struct BlangTarget <: StreamTarget
    #=
    Limitation: this should be called on a pre-compiled blang model, 
    i.e. via a command of the form `java package.MyBlangModel ...`, rather than  
    `blang ...` since the latter could cause several MPI processes to 
    simultaneously attempt to compile in the same directory. 
    =#
    command::Cmd
end

#=  
The only thing that absolutely needs to be implemented on Pigeons' side of the Pigeons-Blang bridge 
is the function below, which passes the rng to the right command line argument,  
calls Blang's Pigeons bridge, and instruct Blang to skips saving standard streams as they will contain 
all the messages between Pigeons and Blang. 
The rest of this file is just convenience function to setup example Blang examples.

The code on Blang's side of the bridge is available at 
this address: 
https://github.com/UBC-Stat-ML/blangSDK/blob/master/src/main/java/blang/engines/internals/factories/Pigeons.java
=#
initialization(target::BlangTarget, rng::AbstractRNG, replica_index::Int64) = 
    StreamState(
        `$(target.command) 
            --experimentConfigs.resultsHTMLPage false
            --experimentConfigs.saveStandardStreams false
            --engine blang.engines.internals.factories.Pigeons 
            --engine.random $(java_seed(rng))`,
        replica_index)

"""
$SIGNATURES 

Model for phylogenetic inference from single-cell copy-number alteration from 
[Salehi et al., 2020](https://www.biorxiv.org/content/10.1101/2020.05.06.058180). 

For more information:
```@example 
using Pigeons

Pigeons.setup_blang("nowellpack") 
run(Pigeons.blang_sitka(`--help`).command);
```
"""
blang_sitka(model_options) = 
    BlangTarget(`$(blang_executable("nowellpack", "corrupt.NoisyBinaryModel")) $model_options`)

"""
$SIGNATURES 

Default options for infering a posterior distribution on 
phylogenetic trees for  
the 535 triple negative breast cancer dataset in 
[Salehi et al., 2020](https://www.biorxiv.org/content/10.1101/2020.05.06.058180).   
"""
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

blang_eight_schools() = 
    BlangTarget(
        `$(blang_executable("blangDemos", "demos.EightSchools")) --model.data $(blang_repo_path("blangDemos"))/data/eight-schools.csv`
    )

blang_unid(model_options = "") = 
    BlangTarget(
        `$(blang_executable("blangDemos", "demos.UnidentifiableProduct")) $model_options`
    )



""" 
$SIGNATURES 

Two-dimensional Ising model.

For more information:
```@example 
using Pigeons

Pigeons.setup_blang("blangDemos") 
run(Pigeons.blang_ising(`--help`).command);

E.g., use arguments `model.N` to set the size 
of the grid. 
```
"""
blang_ising(model_options) = 
    BlangTarget(
        `$(blang_executable("blangDemos", "blang.validation.internals.fixtures.Ising")) $model_options`
    )

"""
$SIGNATURES 

15x15 Ising model. 
"""
blang_ising() = blang_ising(`--model.N 15`)

"""
$SIGNATURES 

Download the github repo with the given `repo_name` and `organization` in ~.pigeons, 
and compile the blang code. 
"""
function setup_blang(
        repo_name, 
        organization = "UBC-Stat-ML")

    auto_install_folder = mkpath(mpi_settings_folder())
    repo_path = "$auto_install_folder/$repo_name"
    if isdir(repo_path)
        @info "it seems setup_blang() was already ran for $repo_name; to force re-runing the setup for $repo_name, first remove the folder $repo_path"
        return nothing
    end

    cd(auto_install_folder) do # NB: github CI does not allow the test code to clone a repo using git@.., so it has to be over https 
        run(`git clone https://github.com/$organization/$repo_name.git`)
    end 

    cd(repo_path) do
        gradle_exec = Sys.iswindows() ? "gradlew.bat" : "gradlew"
        resolved_gradle_exec = abspath("$repo_path/$gradle_exec")
        run(`$resolved_gradle_exec installDist`)
    end 
    return nothing
end

# Internals

blang_repo_path(repo_name) = 
    "$(mkpath(mpi_settings_folder()))/$repo_name"

function blang_executable(repo_name, qualified_main_class)
    repo_path = blang_repo_path(repo_name)
    if !isdir(repo_path)
        error("run Pigeons.setup_blang(\"$repo_name\") first (this only needs to be done once)")
    end
    libs = "$repo_path/build/install/$repo_name/lib/"
    return `java -cp $libs/\* $qualified_main_class`
end