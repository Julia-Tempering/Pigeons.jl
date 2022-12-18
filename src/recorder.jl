"""
Accumulate a specific type of statistic, for example 
by keeping constant size sufficient statistics 
(via `OnlineStat`, which conforms this interface), 
storing samples to a file, etc. 
See also [`recorders`](@ref).
"""
@informal recorder begin
    """
    $(TYPEDSIGNATURES)

    Add `value` to the statistics accumulated by [`recorder`](@ref).
    """
    record!(recorder, value) = @abstract 

    """
    $(TYPEDSIGNATURES)

    Combine the two provided [`recorder`](@ref) objects, and then 
    "dispose" of the two input arguments. 

    At a high-level, we dispose to avoid the same statistic being 
    counted twice. 

    More precisely, for an in-memory recorder, we "empty!" the input arguments to 
    ensure, e.g., that in the next PT round we start collecting statistics 
    from scratch. For file-based recorders, disposing means erasing 
    intermediate files that are no longer needed. 

    By default, call `Base.merge()` followed by `Base.empty!()`
    """
    function combine!(recorder1, recorder2) 
        result = merge(recorder1, recorder2)
        empty!(recorder1)
        empty!(recorder2)
        return result
    end
end

function Base.empty!(x::Mean) 
    x.μ = zero(x.μ)
    x.n = zero(x.n)
    return x
end

function Base.empty!(x::GroupBy)
    x.n = zero(x.n)
    empty!(x.value)
    return x
end

"""
$TYPEDSIGNATURES

Forwards to OnlineStats' `fit!`
"""
record!(recorder::OnlineStat, value) = fit!(recorder, value)

"""
$TYPEDSIGNATURES

Given a `value`, a pair `(a, b)`, and a `Dict{K, Vector{V}}` backed 
[`recorder`](@ref), 
append `b` to the vector corresponding to `a`, inserting an empty 
vector into the dictionary first if needed.
"""
function record!(recorder::Dict{K, Vector{V}}, value::Tuple{K, V}) where {K, V}
    a, b = value
    if !haskey(recorder, a)
        recorder[a] = Vector{V}()
    end
    push!(recorder[a], b)
end

"""
$TYPEDSIGNATURES

A [`recorder`](@ref) storing results to the filesystem. 
Temporary, replica-specific files are first stored in the 
`folder`, and merged at the end of the round. The final file name 
is `[folder]/[name]`.
"""
@provides recorder iostream_recorder(name, folder) = FileRecorder{IOStream}(name, folder, 0, UNDEF_ID, nothing)

# TODO: at least a couple options for iteration/round: in the record!() signature, or as state

const UNDEF_ID = -1
mutable struct FileRecorder{S} where S
    name::String
    folder::String
    round::Int
    id::Int
    stream::Union{S, Nothing}
end

Next:

- kind of have to investigate / get more info on UX...

- recorders need to be given an iteration object (round, iteration); possibly finer scale
- combination of chunks should be separate utility (only do it on single machine?)
- use extra artificial chain with no-op expl and only check-pointing?
- time to think deeply about how samples will get used 
    - keep in mind just standard summaries 99% of use 
    - but could have costly post-process which we also want to MPI!
    - rejuvenation on the fly? 
    - think about distributed M-type - or do the search thing 
    - post-pred check another good thing to keep 

ORTHO: write to Christian et Robin re E[L(X)]-based model selection 
    - fist look at data tempering version

IDEA:
    - keep barebone recorders for adaptation, especially those multi-chained
    - everything else should be based on a nice distributed post-processor,
        including website creation!

combine!(dispatch_recorder, src_file1, src_file2, destination_file) = @abstract
Base.open(dispatch_recorder::FileRecorder{S}, file) = @abstract

function combine!(::FileRecorder{IOStream}, src_file1, src_file2, destination_file)
    open(destination_file, "w") do io
        for line in eachline(src_file1)
            println(io, line)
        end
        for line in eachline(src_file2)
            println(io, line)
        end
    end
end

Base.open(::FileRecorder{IOStream}, file) = open(file, "w")

filename(fr::FileRecorder, temp::Bool) = 
    fr.folder * "/"  * (temp ? "_" : "") * (fr.id == 1 ? "" : string(fr.id) * "_") * name * "_round=" * fr.round

function combine!(recorder1::FileRecorder{T}, recorder2::FileRecorder{T}) where {T} 
    name = recorder1.name
    folder = recorder1.folder
    round = recorder1.round
    @assert name == recorder2.name 
    @assert folder == recorder2.folder
    @assert round == recorder2.round
    
    # close FDs if present
    recorder1.stream === nothing || close(recorder1.stream)
    recorder2.stream === nothing || close(recorder2.stream)

    # move first file to avoid overwritting it
    src_file1 = mv(filename(recorder1, false), filename(recorder1, true))
    src_file2 = filename(recorder2, false)
    dest_file = filename(recorder1, false)

    # merge
    combine!(recorder1, src_file1, src_file2, dest_file)

    # delete files that are no longer needed
    rm(src_file1)
    rm(src_file2)
    empty!(recorder1)
    empty!(recorder2)

    return FileRecorder{T}(name, folder, round + 1, UNDEF_ID, nothing)
end

function Base.empty!(recorder)
    recorder.id = UNDEF_ID 
    recorder.stream = nothing
    recorder.round += 1
end

function record!(recorder::FileRecorder, value)  
    replica_id, payload = value
    if recorder.id == UNDEF_ID
        recorder.id = replica_id
        recorder.stream = open(recorder, filename(recorder, false))
    end
    @assert recorder_id === replica_id
    record!(recorder.stream, payload)
end

record!(io::IOStream, to_write) = println(io, to_write)

