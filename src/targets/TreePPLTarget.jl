""" 
A [`StreamTarget`](@ref) delegating exploration to a
[TreePPL](https://www.treeppl.org/) worker processes.

For installation help, see the official [TreePPL installation instructions](https://treeppl.org/getting-started/getting-started) 

```@example TreePPL_Pigeons
using Pigeons

# Get the TreePPL models
# run(`git clone https://github.com/treeppl/treeppl.git`)
# cd("treeppl") do
#     run(`git checkout 9d35622`) # checkout a specific revision for reproducibility
# end

# Set up paths to a CRBD model 
model_path = "treeppl/models/diversification/crbd.tppl"
bin_path = "treeppl/models/diversification/crbd.bin"
data_path = "treeppl/models/diversification/data/testdata_crbd.json"
output_path = "treeppl/crbd_outputs"

# Compile the TreePPL model with the correct flags using a Docker container with Podman
tppl_bin = Pigeons.tppl_compile_model(
    model_path, bin_path;
    container_engine="docker",
    img_name="docker.io/danielssonerik/treeppl:9d35622"
) 

# Construct the TreePPL target
tppl_target = Pigeons.tppl_construct_target(tppl_bin, data_path, output_path)

# Let Pigeons run the TreePPL model
pt  = pigeons(target = tppl_target, n_rounds = 2, n_chains = 2)
```

Please see https://www.treeppl.org/ for more examples and documentation.
"""

Base.@kwdef struct TreePPLTarget <: StreamTarget
    bin_path::AbstractString
    data_path::AbstractString
    output_dir::AbstractString
    record_samples::Bool
    container_engine::Union{String,Nothing}
    img_name::Union{String,Nothing}
end

# Store the binary path and metadata about how we compiled it
Base.@kwdef struct TreePPLBinary
    model_name::AbstractString
    path::AbstractString
    container_engine::Union{String,Nothing} = nothing
    img_name::Union{String,Nothing} = nothing
    local_exploration_steps::Int
    use_global::Bool
    record_samples::Bool
    sampling_period::Int
    cps::AbstractString
    align::Bool
    kernel::Bool
    drift::Float64
    globalProb::Float64
end

function initialization(target::TreePPLTarget, rng::AbstractRNG, replica_index::Int64)::StreamState
    # Set the seed of the TreePPL process
    envs = Dict{String,Any}("PPL_SEED" => java_seed(rng))
    if target.record_samples
        # Ensure that the output directory exists
        mkpath(target.output_dir)
        # Instruct TreePPL to save samples to file
        envs["PPL_OUTPUT"] = "$(target.output_dir)/tppl-replica-$replica_index.json"
    elseif target.output_dir != ""
        @warn "You have specified an TreePPL output directory but record_samples is set to false. No samples will be recorded."
    end
    # Construct command for running the child process
    if target.container_engine == nothing
        cmd_with_env = `$(target.bin_path) $(target.data_path)`
    elseif target.container_engine in ["docker", "podman"]
        cmd_with_env = construct_docker_podman_run_cmd(
            target.bin_path,
            target.data_path,
            target.img_name,
            target.container_engine,
            envs,
        )
    else
        error("Unsupported container engine: $(target.container_engine)")
    end
    StreamState(cmd_with_env, replica_index)
end

# Helper method to constructing a TreePPL target from a TreePPL binary
# It keeps the compilation metadata we need later on.
function tppl_construct_target(
    binary::TreePPLBinary,
    data_path::AbstractString,
    output_dir::AbstractString=""
)::TreePPLTarget
    return TreePPLTarget(
        bin_path=binary.path,
        data_path=data_path,
        output_dir=output_dir,
        record_samples=binary.record_samples,
        container_engine=binary.container_engine,
        img_name=binary.img_name,
    )
end

function tppl_compile_model(
    model_path::AbstractString, bin::AbstractString="out";
    local_exploration_steps::Int=1, use_global::Bool=true,
    record_samples::Bool=true, sampling_period::Int=1,
    cps::AbstractString="full", align::Bool=true,
    kernel::Bool=true, drift::Float64=1.0,
    globalProb::Float64=0.0,
    tpplc::AbstractString="tpplc",
    container_engine::Union{AbstractString,Nothing}=nothing,
    img_name::Union{AbstractString,Nothing}=nothing
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
        run(construct_docker_podman_compilation_cmd(model_path, bin, args, img_name, container_engine))
    else
        error("Unsupported container engine: $container_engine")
    end

    return TreePPLBinary(
        model_name=basename(model_path),
        path=abspath(bin),
        container_engine=container_engine,
        img_name=img_name,
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

# This function generate a command for running a TreePPL binary inside a
# Docker/Podman container mounts the binary, data and (optionally) output
# directories. 
function construct_docker_podman_run_cmd(
    bin_path::AbstractString,
    data_path::AbstractString,
    img_name::AbstractString,
    container_engine::AbstractString,
    envs::Dict{String,<:Any}
)::Cmd
    if !(container_engine in ["docker", "podman"])
        error("Unsupported container engine: $container_engine")
    end
    volumes = [
        (abspath(dirname(bin_path)), "/in"),
        (abspath(dirname(data_path)), "/data")
    ]

    if "PPL_OUTPUT" in keys(envs)
        # Mount the output directory if we are recording samples
        output_path = envs["PPL_OUTPUT"]
        envs["PPL_OUTPUT"] = "/out/$(basename(output_path))"
        push!(volumes, (abspath(dirname(output_path)), "/out"))
    end
    volume_args = vcat([["-v", "$source:$target"] for (source, target) in volumes]...)
    docker_env_args = vcat([["-e", "$var=$val"] for (var, val) in envs]...)
    # The command we run inside the container needs to be wrapped in a string
    container_sh_cmd = "/in/$(basename(bin_path)) /data/$(basename(data_path))"

     return `
        $container_engine run
        --rm
        -i
        $volume_args
        $docker_env_args
        $img_name
        sh -c "$container_sh_cmd"
    `
end

# This function generates a simple command for running the TreePPL compiler 
# inside a Docker/Podman container. It mounts the model directory and the
# directory where we want the binary. 
function construct_docker_podman_compilation_cmd(
    model_path::AbstractString,
    bin::AbstractString,
    args::Vector,
    img_name::AbstractString,
    container_engine::AbstractString
)::Cmd
    if !(container_engine in ["docker", "podman"])
        error("Unsupported container engine: $container_engine")
    end

    model_dir = abspath(dirname(model_path))
    bin_dir = abspath(dirname(bin))

    container_sh_cmd = "tpplc $(join(args, ' ')) /in/$(basename(model_path)) --output /out/$(basename(bin))"

    return `
    $container_engine run
        --rm
        -v $model_dir:/in
        -v $bin_dir:/out
        $img_name
        sh -c $container_sh_cmd
    `
end