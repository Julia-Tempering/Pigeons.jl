function preflight_checks(pt)
    if pt.inputs.checked_round > 0 && !pt.inputs.checkpoint
        throw(ArgumentError("activate checkpoint when performing checks"))
    end
    if pt.inputs.checked_round < 0 || pt.inputs.checked_round > pt.inputs.n_rounds 
        throw(ArgumentError("set checked_round between 0 and n_rounds inclusively"))
    end
    if typeof(pt.inputs.target) <: StreamTarget && pt.inputs.checkpoint 
        @warn "Checkpoints for StreamTarget do not allow resuming jobs; partial checkpoints (for Shared structs) are still useful for checking Parallelism Invariance"
    end
end

"""
Perform checks to detect software defects. 
Unable via field `checked_round` in [`Inputs`](@ref)
Currently the following checks are implemented:

- [`check_against_serial()`](@ref)
"""
function run_checks(pt)
    if pt.shared.iterators.round != pt.inputs.checked_round
        return 
    end

    only_one_process(pt) do
        #check_serialization(pt) # TODO: check immutables do not change, etc
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
    serial_pt_inputs = deepcopy(pt.inputs)
    serial_pt_inputs.n_rounds = round 
    serial_pt_inputs.checked_round = 0 # <- otherwise infinity loop
    serial_pt_result = pigeons(serial_pt_inputs, on = ChildProcess(n_threads = 1, wait = true))
    serial_checkpoint = "$(serial_pt_result.exec_folder)/round=$round/checkpoint"

    # compare the serialized files
    compare_checkpoints(parallel_checkpoint, serial_checkpoint)
    compare_serialized(
        "$(pt.exec_folder)/immutables.jls", 
        "$(serial_pt_result.exec_folder)/immutables.jls")
end

compare_checkpoints(checkpoint_folder1, checkpoint_folder2) = 
    for file in readdir(checkpoint_folder1)
        if endswith(file, ".jls")
            compare_serialized("$checkpoint_folder1/$file", "$checkpoint_folder2/$file")
        end
    end

function compare_serialized(file1, file2)
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
            """
        )
    end
end

function Base.:(==)(a::GroupBy, b::GroupBy) 
    # as of Jan 2023, OnlineStat uses a default method of 
    # descending into the fields, somehow not valid for GroupBy
    if a.value != b.value 
        return false
    end
    for key in keys(a.value) 
        if a[key] != b[key] 
            return false
        end
    end
    return true
end

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
Base.:(==)(a::SplittableRandom, b::SplittableRandom) = recursive_equal(a, b)
Base.:(==)(a::Replica, b::Replica) = recursive_equal(a, b)    
Base.:(==)(a::Iterators, b::Iterators) = recursive_equal(a, b) 
Base.:(==)(a::Schedule, b::Schedule) = recursive_equal(a, b)
Base.:(==)(a::DEO, b::DEO) = recursive_equal(a, b)
Base.:(==)(a::Shared, b::Shared) = recursive_equal(a, b)
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

function recursive_equal(a::T, b::T) where {T}
    for f in fieldnames(T)
        if getfield(a, f) != getfield(b, f)
            return false
        end
    end
    return true
end