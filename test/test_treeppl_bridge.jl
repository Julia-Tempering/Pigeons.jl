function test_model_runs(
    model::Tuple{AbstractString,AbstractString},
    models_dir::AbstractString,
    container_engine::AbstractString,
    img_name::AbstractString
)
    (subdir, model_name) = model

    # Define directories
    model_path = "$models_dir/$subdir/$model_name.tppl"
    bin_path = "$models_dir/$subdir/$model_name.bin"
    data_path = "$models_dir/$subdir/data/testdata_$model_name.json"
    result_dir = "tppl-$(model_name)-results"

    println("Compiling TreePPL model: $model_name")
    tppl_binary = Pigeons.tppl_compile_model(
        model_path, bin_path;
        local_exploration_steps=2,
        container_engine=container_engine,
        img_name=img_name
    )
    @test isfile(tppl_binary.path)

    println("Constructing TreePPL target for model: $model_name")
    tppl_target = Pigeons.tppl_construct_target(tppl_binary, data_path, result_dir)

    println("Running Pigeons on TreePPL model: $model_name")
    n_chains = 2
    pt = pigeons(target=tppl_target, n_rounds=2, n_chains=n_chains)
    Pigeons.kill_child_processes(pt)

    # Check that the samples seem to correctly written
    println("Checking sample compilation")
    test_sample_compilation(pt, result_dir, n_chains)

    # Remove the result directory
    rm(result_dir, force=true, recursive=true)
    return stepping_stone(pt)
end

function test_sample_compilation(pt::PT, result_dir::AbstractString, n_chains::Int)

    # Check that the result directory contains the output files
    @test all(["tppl-replica-$i.json" in readdir(result_dir) for i in 1:n_chains])

    # Compile the samples 
    compiled_samples_path = "$result_dir/compiled_samples.json"
    Pigeons.tppl_compile_samples(pt, compiled_samples_path)

    # Check that we did not lose any lines in sample compilation
    @test sum(
        [
            length(readlines("$result_dir/tppl-replica-$i.json"))
            for i in 1:n_chains
        ]
    ) == length(readlines(compiled_samples_path))

end

function test_no_record_samples(
    model::Tuple{AbstractString,AbstractString},
    models_dir::AbstractString,
    container_engine::AbstractString,
    img_name::AbstractString
)
    (subdir, model_name) = model

    # Define directories
    model_path = "$models_dir/$subdir/$model_name.tppl"
    bin_path = "$models_dir/$subdir/$model_name.bin"
    data_path = "$models_dir/$subdir/data/testdata_$model_name.json"

    # Compile the model without recording samples
    println("Compiling TreePPL model: $model_name")
    tppl_binary = Pigeons.tppl_compile_model(
        model_path, bin_path;
        local_exploration_steps=2,
        record_samples=false,
        container_engine=container_engine,
        img_name=img_name
    )

    tppl_target = Pigeons.tppl_construct_target(tppl_binary, data_path)

    pt = pigeons(target=tppl_target, n_rounds=2, n_chains=2)
    Pigeons.kill_child_processes(pt)
    return stepping_stone(pt)
end

# Small normalizing and mean constant test
# This test works when the model has scalar float output
function test_inference_accuracy(
    model::Tuple{AbstractString,AbstractString},
    models_dir::AbstractString,
    data_path::AbstractString,
    container_engine::AbstractString,
    img_name::AbstractString,
    norm_const::Float64,
    ϵ_norm_const::Float64,
    true_mean::Float64,
    ϵ_mean::Float64,
    n_rounds::Int,
    n_chains::Int
)
    (subdir, model_name) = model

    # Define directories
    model_path = "$models_dir/$subdir/$model_name.tppl"
    bin_path = "$models_dir/$subdir/$model_name.bin"
    result_dir = "tppl-inference-accurracy-$(model_name)-results"

    # Compile the model without recording samples
    tppl_binary = Pigeons.tppl_compile_model(
        model_path, bin_path;
        local_exploration_steps=10,
        use_global=true,
        record_samples=true,
        sampling_period=1,
        cps="full",
        align=true,
        kernel=true,
        drift=1.0,
        globalProb=0.1,
        container_engine=container_engine,
        img_name=img_name
    )

    tppl_target = Pigeons.tppl_construct_target(tppl_binary, data_path, result_dir)

    pt = pigeons(target=tppl_target, n_rounds=n_rounds, n_chains=n_chains)
    Pigeons.kill_child_processes(pt)

    # Check that the norm const estimate is roughly correct
    est_norm_const = stepping_stone(pt)
    @test abs(est_norm_const - norm_const) < ϵ_norm_const

    # Check that the mean of the samples is (roughly) correct
    compiled_samples_path = "$result_dir/compiled_samples.json"
    Pigeons.tppl_compile_samples(pt, compiled_samples_path)

    est_mean = mean([parse(Float64, v) for v in readlines(compiled_samples_path)])

    @test abs(est_mean - true_mean) < ϵ_mean
end

function test_inference_accuracy_coin(
    models_dir::AbstractString,
    container_engine::AbstractString,
    img_name::AbstractString
)
    model = tppl_coin_model()
    (subdir, model_name) = model
    N = 10
    data = [i % 2 == 0 for i in 1:N]

    data_path = "$models_dir/$subdir/data/$(model_name)_N$(N)_data.json"
    open(data_path, "w") do f
        JSON.print(f, Dict("coinflips" => data))
    end

    # Analytical normalizing constant for Beta(2, 2) prior
    α = 2.0
    β = 2.0
    logZ₀ = SpecialFunctions.logbeta(α, β)
    logZ₁ = SpecialFunctions.logbeta(α + sum(data), β + N - sum(data))
    norm_const = logZ₁ - logZ₀
    ϵ_norm_const = 0.05

    # Analytical posterior mean for Beta(2, 2) prior
    true_mean = (α + sum(data)) / (α + β + N)
    ϵ_mean = 1e-4

    test_inference_accuracy(
        model, models_dir, data_path,
        container_engine, img_name,
        norm_const, ϵ_norm_const,
        true_mean, ϵ_mean,
        10, 4
    )

    # Remove the data file
    rm(data_path, force=true)
end

# Define a few TreePPL models for testing
tppl_coin_model() = ("lang", "coin")
tppl_crbd_model() = ("diversification", "crbd")
tppl_HRM_model() = ("host-repertoire-evolution", "flat-root-prior-HRM")

@testset "TreePPL runs" begin
    if !(Sys.islinux() && Sys.ARCH == :x86_64)
        @info "Skipping TreePPL tests since they only run on Linux x86-64 in CI at the moment."
        return nothing
    end

    auto_install_folder = mkpath(Pigeons.mpi_settings_folder())
    cd(auto_install_folder) do
        # Clone the TreePPL repo to get access to models
        # NOTE(ErikDanielsson) 2025-11-13: I have set the revision to the HEAD 
        # commit of the main repo at the time of the Pigeons support merge. 
        # TODO: This should be set to a release version (or multiple) once
        # there is one. The same holds for Docker containers which are
        # currently not officially from TreePPL
        revision = "597a65a"
        rel_loc = "treeppl"

        # Ensure that the directory does not exist
        rm(rel_loc, force=true, recursive=true)
        run(`git clone https://github.com/treeppl/treeppl.git $rel_loc`)

        cd(rel_loc) do
            # Ensure that the desired revision is checked out
            run(`git checkout $revision`)
        end

        container_engine = "docker"
        # The Docker container tag should match the checked out repository
        tppl_img_name = "docker.io/danielssonerik/treeppl:$revision"

        models_dir = abspath("treeppl/models")
        models = [
            tppl_coin_model(),
            tppl_crbd_model(),
            tppl_HRM_model()
        ]

        # Try compiling the models using the Docker container 
        for model in models
            norm_const_1 = test_model_runs(model, models_dir, container_engine, tppl_img_name)
            norm_const_2 = test_no_record_samples(model, models_dir, container_engine, tppl_img_name)
            # Check that recording samples does not effect inference (this would be a bug in TreePPL)
            @test norm_const_1  == norm_const_2
        end

        # Test inference accuracy in the Beta-Binomial model 
        # NOTE(ErikDanielsson 19-12-2025): We might want to replace this with a
        # phylogenetic model once tempering of hard constraints are handled in a
        # more natural way in TreePPL
        test_inference_accuracy_coin(models_dir, container_engine, tppl_img_name)
    end
end