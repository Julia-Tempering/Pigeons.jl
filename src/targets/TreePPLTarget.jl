""" 
A [`StreamTarget`](@ref) delegating exploration to a
[TreePPL](https://www.treeppl.org/) worker processes.

For installation help, see the official [TreePPL installation instructions](https://treeppl.org/getting-started/getting-started) 

```@example TreePPL_Pigeons
using Pigeons

# Get the TreePPL models
run(`git clone https://github.com/treeppl/treeppl.git`)

# Set up paths to a CRBD model 
model_path = treeppl/models/diversification/crbd.tppl
bin_path = treeppl/models/diversification/crbd.bin
data_path = treeppl/models/lang/data/testdata_crbd.json
result_path = treeppl/crbd_results

# Compile the TreePPL model with the correct flags using a Docker container with Podman
tppl_bin = tppl_compile_model(
    model_path, bin_path;
    container_engine="podman",
    img_name="docker.io/danielssonerik/treeppl:main
) 

# Construct the TreePPL target
tppl_target = tppl_construct_target(tppl_bin, data_path, result_path)

# Let Pigeons run the TreePPL model
pigeons(target = tppl_target));
```
"""

struct TreePPLTarget <: StreamTarget
    command::Cmd
    record_samples::Bool
    output_dir::AbstractString
end

function initialization(target::TreePPLTarget, rng::AbstractRNG, replica_index::Int64)
    # Set the seed of the TreePPL process
    envs = Pair{String, Any}["PPL_SEED" => java_seed(rng)]
    if target.record_samples 
        # Ensure that the output directory exists
        mkpath(target.output_dir) 
        # Instruct TreePPL to save samples to file
        push!(envs, "PPL_OUTPUT" => "$(target.output_dir)/tppl-replica-$replica_index.json")
    elseif target.output_dir != ""
        @warn "You have specified an TreePPL output directory but record_samples is set to false. No samples will be recorded."
    end
    cmd_with_env = addenv(target.command, envs...)
    StreamState(cmd_with_env, replica_index)
end

# Store the binary path and metadata about how we compiled it
Base.@kwdef struct TreePPLBinary
    model_name::AbstractString
    path::AbstractString
    local_exploration_steps::Int
    use_global::Bool
    record_samples::Bool
    sampling_period::Int
    cps::String
    align::Bool
    kernel::Bool
    drift::Float64
    globalProb::Float64
end

function tppl_construct_target(
    binary::TreePPLBinary,
    data_path::AbstractString,
    result_dir::AbstractString=""
)::TreePPLTarget
    cmd = Cmd([binary.path, data_path])
    return TreePPLTarget(cmd, binary.record_samples, result_dir)
end

function construct_docker_podman_cmd(
    model_path::AbstractString,
    bin::AbstractString,
    args::Vector,
    img_name::AbstractString,
    container_engine::AbstractString
)
    if !(container_engine in ["docker", "podman"])
        # This should be caught upstream
        return nothing
    end

    model_dir = abspath(dirname(model_path))
    bin_dir = abspath(dirname(bin))
    container_sh_cmd = string(`tpplc $args /in/$(basename(model_path)) --output /out/$(basename(bin))`)
    # This simple command for running the TreePPL compiler mounts the model directory and the directory
    # where we want the binary. It then calls the compiler inside the container with the arguments.
    return `
    $container_engine run
        --rm
        -v $model_dir:/in
        -v $bin_dir:/out
        $img_name
        sh -c "$container_sh_cmd"
    `
end

function tppl_compile_model(
    model_path::AbstractString, bin::AbstractString="out";
    local_exploration_steps::Int=1, use_global::Bool=true,
    record_samples::Bool=true, sampling_period::Int=1,
    cps::String="full", align::Bool=true,
    kernel::Bool=true, drift::Float64=1.0,
    globalProb::Float64=0.0,
    tpplc="tpplc",
    container_engine::Union{String, Nothing}=nothing,
    img_name::Union{String, Nothing}=nothing
)::TreePPLBinary
    if !(cps in ["none", "full", "partial"])
        error("Only `--cps none`, `--cps full` and `--cps partial` are allowed.")
    end

    # TreePPL only supports Pigeons when running lightweight MCMC. 
    # Please see `tpplc --help` for explanations of what each argument does
    args = [
        "-m", "mcmc-lightweight",
        "--pigeons",
        "--pigeons-explore-steps", local_exploration_steps,
        "--cps", cps,
        "--mcmc-lw-gprob", globalProb,
        "--drift", drift,
        "--sampling-period", sampling_period,
    ]
    flags = [
        (!use_global, "--pigeons-no-global"),
        (kernel, "--kernel"),
        (align, "--align"),
        (record_samples, "--incremental-printing"),
    ]
    args = vcat(args, [flag for (cond, flag) in flags if cond])

    # Compile the model
    if container_engine == nothing
        run(`$tpplc $args $model_path --output $bin`)
    elseif container_engine in ["podman", "docker"]
        run(construct_docker_podman_cmd(model_path, bin, args, img_name, container_engine))
    else
        error("Unsupported container engine: $container_engine")
    end

    return TreePPLBinary(
        model_name=basename(model_path),
        path=abspath(bin),
        local_exploration_steps=local_exploration_steps,
        use_global=use_global,
        record_samples=record_samples,
        sampling_period=sampling_period,
        cps=cps,
        align=align,
        kernel=kernel,
        drift=drift,
        globalProb=globalProb
    )
end