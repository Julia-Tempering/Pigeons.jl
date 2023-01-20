using Pigeons 

if !isdir("nowellpack") && !islink(blang_repo)
    # Download and compile the Blang model used in https://www.biorxiv.org/content/10.1101/2020.05.06.058180
    run(`git clone git@github.com:UBC-Stat-ML/nowellpack.git`)
    cd("nowellpack") do 
        run(`setup-cli`)
    end
end

blang_model = 
    Pigeons.BlangTarget(
        `nowellpack/build/install/nowellpack/bin/corrupt-infer-with-noisy-params
            --model.binaryMatrix nowellpack/examples/535/filtered.csv 
            --model.globalParameterization true 
            --model.fprBound 0.005 
            --model.fnrBound 0.5 
            --model.minBound 0.001  
            --model.samplerOptions.useCellReallocationMove true  
            --model.predictivesProportion 0.0  
            --model.samplerOptions.useMiniMoves true`
    );


