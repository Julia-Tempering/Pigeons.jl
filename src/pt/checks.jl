function preflight_checks(inputs::Inputs)
    if isdisjoint([traces, disk, online], inputs.record)
        @info """Neither traces, disk, nor online recorders included. 
                 You may not have access to your samples (unless you are using a custom recorder, or maybe you just want log(Z)).
                 To add recorders, use e.g. pigeons(target = ..., record = [traces; record_default()])
              """
    end
    if mpi_active() && !inputs.checkpoint
        @warn "To be able to call load() to retrieve samples in-memory, use pigeons(target = ..., checkpoint = true)"
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
            # this process was itself spawn using ChildProcess/MPI 
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

function compare_serialized(file1, file2, immutables = nothing)
    first  = deserialize(file1)
    second = deserialize(file2)
    if first != second
        error(
            """
            detected non-reproducibility, to investigate, type in the REPL:
            ─────────────────────────────────
             using Serialization
             first  = deserialize("$file1");
             second = deserialize("$file2");
            ─────────────────────────────────
            If you are using custom stuct, either mutable or containing 
            mutables, you may just need to add custom ==, see 
            src/pt/checks.jl.
            """
        )
    end
end

function Base.:(==)(a::GroupBy, b::GroupBy) 
    # as of Jan 2023, OnlineStat uses a default method of 
    # descending into the fields, which is somehow not valid for GroupBy, 
    # probably due to undeterminism of underlying OrderedCollections.OrderedDict
    common_keys = keys(a)
    if common_keys != keys(b)
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
Base.:(==)(a::CovMatrix, b::CovMatrix) = value(a) == value(b)

Base.keys(a::GroupBy) = keys(a.value)

function Base.:(==)(a::DynamicPPL.TypedVarInfo, b::DynamicPPL.TypedVarInfo)
    # as of Jan 2023, DynamicPPL does not supply == for TypedVarInfo
    if length(a.metadata) != length(b.metadata)
        return false
    end
    for i in 1:length(a.metadata)
        if a.metadata[i].vals != b.metadata[i].vals
            return false
        end
    end
    return true
end

#= 
Since the state reside in different processes, there are not generic way to 
check equality. 
But we still want to perform checks on the rest of the PT state 
(chain, Shared, rngs, etc), so we return true for now.

TODO: in the future, add an optional get_hash() in the Stream protocol 
to improve this.
=#
Base.:(==)(a::StreamState, b::StreamState) = true
Base.:(==)(a::NonReproducible, b::NonReproducible) = true

# TODO: maybe move this to a sub-module in which == is nicer by default?
# mutable (incl imm with mut fields) structs do not have a nice ===, overload those:
Base.:(==)(a::StanState, b::StanState) = recursive_equal(a, b)
Base.:(==)(a::SplittableRandom, b::SplittableRandom) = recursive_equal(a, b)
Base.:(==)(a::Replica, b::Replica) = recursive_equal(a, b) 
Base.:(==)(a::Augmentation, b::Augmentation) = recursive_equal(a, b) 
Base.:(==)(a::AutoMALA, b::AutoMALA) = recursive_equal(a, b)  
Base.:(==)(a::SliceSampler, b::SliceSampler) = recursive_equal(a, b) 
Base.:(==)(a::Compose, b::Compose) = recursive_equal(a, b)    
Base.:(==)(a::Iterators, b::Iterators) = recursive_equal(a, b) 
Base.:(==)(a::Schedule, b::Schedule) = recursive_equal(a, b)
Base.:(==)(a::DEO, b::DEO) = recursive_equal(a, b)
Base.:(==)(a::Shared, b::Shared) = recursive_equal(a, b, [:reports])
Base.:(==)(a::BlangTarget, b::BlangTarget) = recursive_equal(a, b)
Base.:(==)(a::NonReversiblePT, b::NonReversiblePT) = recursive_equal(a, b)
Base.:(==)(a::InterpolatingPath, b::InterpolatingPath) = recursive_equal(a, b)
Base.:(==)(a::DynamicPPL.Model, b::DynamicPPL.Model) = recursive_equal(a, b)
Base.:(==)(a::DynamicPPL.ConditionContext, b::DynamicPPL.ConditionContext) = recursive_equal(a, b)
Base.:(==)(a::TuringLogPotential, b::TuringLogPotential) = recursive_equal(a, b)
Base.:(==)(a::InterpolatedLogPotential, b::InterpolatedLogPotential) = recursive_equal(a, b)
Base.:(==)(a::RoundTripRecorder, b::RoundTripRecorder) = recursive_equal(a, b)
Base.:(==)(a::OnlineStateRecorder, b::OnlineStateRecorder) = recursive_equal(a, b)
Base.:(==)(a::LocalBarrier, b::LocalBarrier) = recursive_equal(a, b)

Base.:(==)(a::StanLogPotential, b::StanLogPotential) = 
    a.data == b.data && BridgeStan.name(a.model) == BridgeStan.name(b.model)

function recursive_equal(a::T, b::T, exclude = []) where {T}
    for f in fieldnames(T)
        if !(f in exclude) && (getfield(a, f) != getfield(b, f)) 
            return false
        end
    end
    return true
end

