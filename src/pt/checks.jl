function preflight_checks(inputs::Inputs)
    if isdisjoint([traces, disk, online], inputs.record)
        @info """Neither traces, disk, nor online recorders included.
                 You may not have access to your samples (unless you are using a custom recorder, or maybe you just want log(Z)).
                 To add recorders, use e.g. pigeons(target = ..., record = [traces; record_default()])
              """
    end
    if !isnothing(inputs.variational) && inputs.target isa MultiStepsInterpolatingPath 
        # would need to fit variational to closest knot instead of target
        throw(ArgumentError("Variational inference not currently supported with MultiStepsInterpolatingPath"))
    end
    if mpi_active() && !inputs.checkpoint
        @warn "To be able to call Pigeons.load() to retrieve samples in-memory, use pigeons(target = ..., checkpoint = true)"
    end
    if Threads.nthreads() > 1 && !inputs.multithreaded
        @warn "More than one threads are available, but explore!() loop is not parallelized as inputs.multithreaded == false"
    end
    if inputs.checked_round > 0 && !inputs.checkpoint
        throw(ArgumentError("activate checkpoint when performing checks"))
    end
    if disk in inputs.record && !inputs.checkpoint
        throw(ArgumentError("activate checkpoint when using the disk recorder"))
    end
    if inputs.checked_round < 0 || inputs.checked_round > inputs.n_rounds
        throw(ArgumentError("set checked_round between 0 and n_rounds inclusively"))
    end
    if typeof(inputs.target) <: StreamTarget && inputs.checkpoint
        @warn "Checkpoints for StreamTarget do not allow resuming jobs; partial checkpoints (for Shared structs) are still useful for checking Parallelism Invariance"
    end
end

# when pt_arguments is a string, this means we are resuming an
# execution, hence the preflight checks have been performed already
preflight_checks(pt_arguments::String) = nothing

"""
Perform checks to detect software defects.
Unable via field `checked_round` in [`Inputs`](@ref)
"""
function run_checks(pt)
    if pt.shared.iterators.round != pt.inputs.checked_round
        return
    end

    only_one_process(pt) do
        check_against_serial(pt)
    end
end

"""
$SIGNATURES
Run a separate, fully serial version of the PT algorithm,
and compare the checkpoint files to ensure the two
produce exactly the same output.
"""
function check_against_serial(pt)
    round = pt.shared.iterators.round
    parallel_checkpoint = "$(pt.exec_folder)/round=$round/checkpoint"

    # run a serial copy
    dependencies =
        if isfile("$(pt.exec_folder)/.dependencies.jls")
            # this process was itself spawn using ChildProcess/MPIProcesses
            # so use the same dependencies as this process
            deserialize("$(pt.exec_folder)/.dependencies.jls")
        else
            []
        end
    serial_pt_inputs = deepcopy(pt.inputs)
    serial_pt_inputs.n_rounds = round
    serial_pt_inputs.checked_round = 0 # <- otherwise infinity loop
    serial_pt_result = pigeons(serial_pt_inputs, on = ChildProcess(; n_threads = 1, wait = true, dependencies))
    serial_checkpoint = "$(serial_pt_result.exec_folder)/round=$round/checkpoint"

    # compare the serialized files
    immutables = "$(pt.exec_folder)/immutables.jls"
    deserialize_immutables!(immutables)
    compare_checkpoints(parallel_checkpoint, serial_checkpoint, immutables)
    compare_serialized(
        "$(pt.exec_folder)/immutables.jls",
        "$(serial_pt_result.exec_folder)/immutables.jls")
end

compare_checkpoints(checkpoint_folder1, checkpoint_folder2, immutables) =
    for file in readdir(checkpoint_folder1)
        if endswith(file, ".jls")
            compare_serialized("$checkpoint_folder1/$file", "$checkpoint_folder2/$file")
        end
    end

function compare_serialized(file1, file2)
    first  = deserialize(file1)
    second = deserialize(file2)
    if !recursive_equal(first, second)
        error(
            """
            detected non-reproducibility, to investigate, type in the REPL:
            ─────────────────────────────────
             using Serialization
             first  = deserialize("$file1");
             second = deserialize("$file2");
            ─────────────────────────────────
            If you are using a custom struct, either mutable or containing
            mutables, you may just need to extend `recursive_equal`; see
            src/pt/checks.jl.
            """
        )
    end
end


"""
$SIGNATURES
Recursively check equality between two objects by comparing their fields.
By default calls `==` but for certain types we dispatch a custom method. 
This is necessary because for some mutable structs (and even immutable ones with
mutable fields) `==` actually dispatches `===`. The latter is too strict for the 
purpose of checking that two checkpoints are equal.

If you are using custom struct and encounter a failed correctness check, you may
need to provide a special equality check for this type. In most cases it will be
enough to overload `recursive_equal` as follows
```julia
Pigeons.recursive_equal(a::MyType, b::MyType) = Pigeons._recursive_equal(a,b)
```
For examples of more specific checks, refer to the code of `PigeonsBridgeStanExt`.
"""
recursive_equal(a, b) = a==b

#=
For types on this list, we use the default recursive version `_recursive_equal`.
Note that this list is not exhaustive; some types in Pigeons' extensions
also call `_recursive_equal`.
=#
const RecursiveEqualInnerType = 
    Union{
        StanState, SplittableRandom, Replica, Augmentation, AutoMALA, SliceSampler,
        Compose, Mix, Iterators, Schedule, DEO, BlangTarget, NonReversiblePT,
        InterpolatingPath, InterpolatedLogPotential, RoundTripRecorder,
        OnlineStateRecorder, LocalBarrier, NamedTuple, Tuple, Inputs
    }
recursive_equal(a::RecursiveEqualInnerType, b::RecursiveEqualInnerType) =
    _recursive_equal(a,b)
function _recursive_equal(a::T, b::T, exclude::NTuple{N,Symbol}=()) where {T,N}
    for f in fieldnames(T)
        if !(f in exclude || recursive_equal(getfield(a, f), getfield(b, f)))
            println("$f is different between a and b:\n\ta.f=$(getfield(a, f))\n\tb.f=$(getfield(b, f))")
            return false
        end
    end
    return true
end
_recursive_equal(a,b,exclude=nothing) = false # generic case catches difference in types of a and b

# handle arrays of RecursiveEqualInnerType separately
function recursive_equal(
    a::AbstractArray{<:RecursiveEqualInnerType}, 
    b::AbstractArray{<:RecursiveEqualInnerType}
    )
    size(a) == size(b) && all(t -> recursive_equal(t...), zip(a,b))
end

# types for which some fields need to be excluded
recursive_equal(a::Shared, b::Shared) = _recursive_equal(a, b, (:reports,))

#=
leaf methods of recursive_equal: these do not need to be recursive but are still
needed in place of the default `==`.
=#
function recursive_equal(a::GroupBy, b::GroupBy)
    # as of Jan 2023, OnlineStat uses a default method of
    # descending into the fields, which is somehow not valid for GroupBy,
    # probably due to undeterminism of underlying OrderedCollections.OrderedDict
    common_keys = keys(a.value)
    if common_keys != keys(b.value)
        return false
    end
    for key in common_keys
        if a[key] != b[key]
            return false
        end
    end
    return true
end

# CovMatrix contains a cache matrix, which is NaN until value(.) is called
recursive_equal(a::CovMatrix, b::CovMatrix) = value(a) == value(b)

#=
Since the state reside in different processes, there are not generic way to
check equality.
But we still want to perform checks on the rest of the PT state
(chain, Shared, rngs, etc), so we return true for now.

TODO: in the future, add an optional get_hash() in the Stream protocol
to improve this.
=#
recursive_equal(a::StreamState, b::StreamState) = true
recursive_equal(a::NonReproducible, b::NonReproducible) = true
