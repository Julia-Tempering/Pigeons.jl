
"""
    $(TYPEDEF)

Array convience wrapper for [`traces`](@ref) reduced recorder. We require a [`PT`](@ref)
object, and the `chain` number which specifies the chain index (has to be a target chain)
you wish to extract.

This should not be called directly and the user should instead look at [`get_sample`](@ref).
"""
struct SampleArray{T,PT} <: AbstractVector{T}
    pt::PT
    chain::Int
    function SampleArray(pt::P, chain::Int) where {P<:PT}
        rr = pt.reduced_recorders
        T = typeof(get_sample(pt, chain, 1))
        @assert (:traces ∈ propertynames(rr)) "trace recorder not found, did you include it in your run?"
        return new{T,PT}(pt, chain)
    end
end

Base.size(s::SampleArray) = (length(s.pt.reduced_recorders.traces),)
Base.IndexStyle(::Type{<:SampleArray}) = IndexLinear()
Base.getindex(s::SampleArray, i::Int) = get_sample(s.pt, s.chain, i)
Base.setindex!(::SampleArray, i::Int) = error("You can not set the elements of SampleArray")

"""
$(SIGNATURES)
"""
get_sample(pt::PT, chain::Int) = SampleArray(pt, chain)



function Base.show(io::IO, s::SampleArray{T,PT}) where {T,PT}
    println(io, "SampleArray{$T}")
    println(io, "\ttarget chain id:   $(s.chain)")
    println(io, "\tnumber of samples: $(length(s))")
end


"""
$SIGNATURES
"""
get_sample(pt::PT, chain::Int, scan::Int) = pt.reduced_recorders.traces[chain => scan]

"""
$SIGNATURES
"""
process_samples(processor::Function, pt::PT, round::Int = latest_checkpoint_folder(pt.exec_folder)) =
    process_samples(processor, pt.exec_folder, round)

"""
$SIGNATURES
"""
process_samples(processor::Function, pt::Result{PT}, round::Int = latest_checkpoint_folder(pt.exec_folder)) =
    process_samples(processor, pt.exec_folder, round)


"""
$SIGNATURES

Process samples that were saved to disk using the `disk` recorder, at the
given `round`.

Each sample is passed to the `processor` function, by calling
`processor(chain_index, scan_index, sample)` where
`chain_index` is the index of the target chain (in classical parallel tempering,
there is only one chain at target temperature, so in that case it can be ignored,
but it will be non-trivial in e.g. stabilized variational parallel tempering),
`scan_index` is the iteration index
within the round, starting at 1, and sample is the deserialized sample.

This iterates over the samples in increasing order, looping over `chain_index` in the
outer loop and `scan_index` in the inner loop.
"""
function process_samples(processor::Function, exec_folder::String, round::Int)
    if round == 0
        error("no checkpoint is available yet for $exec_folder")
    elseif round < 0
        throw(ArgumentError("round should be positive"))
    end

    deserialize_immutables!("$exec_folder/immutables.jls")
    samples_dir = "$exec_folder/round=$round/samples"
    # open readers
    readers = Dict{String, ZipFile.Reader}()
    for file in readdir(samples_dir)
        if startswith(file, "replica=")
            readers[file] = ZipFile.Reader("$samples_dir/$file")
        end
    end

    # build the samples_layout, i.e.:
    #   for a given scan index, get a ZipFile.ReadableFile to the zip internal file
    samples_layout = Dict{Pair{Int, Int}, ZipFile.ReadableFile}()
    n_scans = 0
    target_chains_set = Set{Int}()
    for reader in values(readers)
        for zip_internal_file in reader.files
            code = Base.split(zip_internal_file.name, '_')
            chain = parse(Int, code[1])
            scan = parse(Int, code[2])
            @assert !haskey(samples_layout, scan)
            key = chain => scan
            samples_layout[key] = zip_internal_file
            n_scans = max(n_scans, scan)
            push!(target_chains_set, chain)
        end
    end

    chains = collect(target_chains_set)
    sort!(chains)

    for chain in chains
        for scan in 1:n_scans
            key = chain => scan
            zip_internal_file = samples_layout[key]
            sample = deserialize(zip_internal_file)
            processor(chain, scan, sample)
        end
    end

    # close readers
    close.(values(readers))

    return nothing
end
