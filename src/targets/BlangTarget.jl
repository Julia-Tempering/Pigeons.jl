""" 
A [`StreamTarget`](@ref) delegating exploration to 
[Blang worker processes](https://www.stat.ubc.ca/~bouchard/blang/). 

To use it, make sure Java 11 is installed and in your 
[PATH variable](https://en.wikipedia.org/wiki/PATH_(variable)), then 
follow this example:

```@example Blang_Pigeons
using Pigeons

pigeons(target = BlangTarget(`\$(blang_command()) --model blang.validation.internals.fixtures.Ising`)) 
```

Here this runs MCMC on Blang's
[built-in Ising model](https://github.com/UBC-Stat-ML/blangSDK/blob/master/src/main/java/blang/validation/internals/fixtures/Ising.bl).

Limitation: at the 
"""
struct BlangTarget <: StreamTarget
    command::Cmd
end

function blang_command()
    cmd = Sys.iswindows() ? "blang.bat" : "blang"
    if cmd_exists(cmd)
        return cmd 
    end
    auto_install_folder = mpi_settings_folder()
    auto_install_folder_cmd = "$auto_install_folder/blangSDK/build/install/blang/bin/$cmd"
    if cmd_exists(auto_install_folder_cmd) 
        return auto_install_folder_cmd 
    end

    println("One-time blang installation into ~/.pigeons/ (this may fail if java 11 is not installed)")

    if isdir("$auto_install_folder/blangSDK")
        error("remove the folder $auto_install_folder/blangSDK")
    end

    mkpath(auto_install_folder)

    cd(auto_install_folder) do
        run(`git clone git@github.com:UBC-Stat-ML/blangSDK.git`)
    end

    cd("$auto_install_folder/blangSDK") do 
        run(`setup-cli`)
    end

    return auto_install_folder_cmd
end

initialization(target::BlangTarget, rng::SplittableRandom, replica_index::Int64) = 
    StreamState(
        `$(target.command) 
            --experimentConfigs.resultsHTMLPage false
            --experimentConfigs.saveStandardStreams false
            --engine blang.engines.internals.factories.Pigeons 
            --engine.random $(java_seed(rng))`,
        replica_index)