""" 
A [`StreamTarget`](@ref) delegating exploration to a
[TreePPL](https://www.treeppl.org/) worker processes.

To install TreePPL locally please see the  official [TreePPL installation instructions](https://treeppl.org/getting-started/getting-started).
TreePPL can also be run inside Docker or Podman containers, e.g.

```@example TreePPL_Pigeons
using Pigeons

# Get the TreePPL models
run(`git clone https://github.com/treeppl/treeppl.git`)
cd("treeppl") do
    run(`git checkout 9d35622`) # checkout a specific revision for reproducibility
end

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

Please see [treeppl.org](https://www.treeppl.org/) for more examples and documentation.

$FIELDS
"""
Base.@kwdef struct TreePPLTarget <: StreamTarget

    """
    The path to the TreePPL binary to be executed.
    """
    bin_path::String

    """
    The path to the input data JSON file.
    """
    data_path::String

    """
    The directory path where TreePPL will save output samples.
    """
    output_dir::String

    """
    Whether the binary should be set up to record samples.
    Note: This requires that the TreePPL binary was compiled with `record_samples=true` in the
    [`tppl_compile_model`](@ref) function or with the `--incremental-printing` flag if the
    model was compiled manually.
    """
    record_samples::Bool

    """
    The container engine to use for running the TreePPL binary.
    Only "docker" and "podman" are supported.
    """
    container_engine::Union{String,Nothing}

    """
    The container image name where the TreePPL binary should be run
    """
    img_name::Union{String,Nothing}
end

"""
$SIGNATURES

A struct representing a compiled TreePPL binary along with metadata about how
it was compiled.

The TreePPLBinary should be constructed by compiling the model with the
[`tppl_compile_model`](@ref) function to ensure that all compilation metadata
is kept. The fields below map directly to options in the [`tppl_compile_model`](@ref)
function. For more information about what each field means, please see the
[`tpplc --help`] command or visit [treeppl.org](https://www.treeppl.org/).

$FIELDS
"""
Base.@kwdef struct TreePPLBinary

    """
    The path to the compiled TreePPL binary
    """
    path::String

    """
    The container engine to use for running the TreePPL binary.
    Only "docker" and "podman" are supported.
    """
    container_engine::Union{String,Nothing} = nothing

    """
    The container image name where the TreePPL binary was compiled
    """
    img_name::Union{String,Nothing} = nothing

    """
    The number of local exploration steps to perform before communicating 
    with Pigeons
    """
    local_exploration_steps::Int

    """
    Whether the binary was compiled to use global proposals at temperature 0.
    """
    use_global::Bool

    """
    Whether the binary was compiled to record samples.
    """
    record_samples::Bool

    """
    The frequency of sample recording in terms of steps in the local kernel.
    """
    sampling_period::Int

    """
    The type of [CPS](https://en.wikipedia.org/wiki/Continuation-passing_style) transformation applied to the model.
    """
    cps::String

    """
    Whether the model was compiled to use the [aligned lightweight MCMC algorithm](https://arxiv.org/abs/2301.11664).
    """
    align::Bool

    """
    Whether the model was compiled to use non-independent updates (drift kernels) at each assume statement.
    """
    kernel::Bool

    """
    The scale of the proposal distribution for the drift kernels.
    """
    drift::Float64

    """
    The probability of redrawing the whole program per local exploration step.
    """
    globalProb::Float64
end

function initialization(target::TreePPLTarget, rng::AbstractRNG, replica_index::Int64)::StreamState
    # Set the seed of the TreePPL process
    bin_env = Dict{String,Any}("PPL_SEED" => java_seed(rng))
    if target.record_samples
        # Ensure that the output directory exists
        mkpath(target.output_dir)
        # Instruct TreePPL to save samples to file
        bin_env["PPL_OUTPUT"] = "$(target.output_dir)/tppl-replica-$replica_index.json"
    elseif target.output_dir != ""
        @warn "You have specified an TreePPL output directory but `record_samples` is set to false. No samples will be recorded."
    end

    # Construct the command for running the child process
    if target.container_engine == nothing
        cmd_with_env = addenv(`$(target.bin_path) $(target.data_path)`, bin_env)
    elseif target.container_engine in ["docker", "podman"]
        cmd_with_env = construct_docker_podman_run_cmd(
            target.bin_path,
            target.data_path,
            target.img_name,
            target.container_engine,
            bin_env,
        )
    else
        error("Unsupported container engine: $(target.container_engine)")
    end
    StreamState(cmd_with_env, replica_index)
end

"""
$SIGNATURES

Construct a [`TreePPLTarget`](@ref) from a [`TreePPLBinary`](@ref)
and keeps necessary metadata about how the binary was compiled.
"""
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

"""
$SIGNATURES

Compile a TreePPL model with a lightweight MCMC inference algorithm.

The arguments `container_engine` and `img_name` can be used to run the TreePPL compiler
inside a Docker or Podman container. See [`TreePPLTarget`](@ref) for an example.
Set to `nothing` to use a local TreePPL installation.

The the rest of the function arguments map to command line arguments in the TreePPL compiler. 
For more information, run `tpplc --help` in your terminal or visit (treeppl.org)[https://www.treeppl.org/].
"""
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


# This function generates a command for running a TreePPL binary inside a
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

    # We need the -i flag to make sure that we can communicate over std streams 
    # with the TreePPL process 
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

    # The command we run inside the container needs to be wrapped in a string
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