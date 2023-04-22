mutable struct DiskRecorder
    file::Union{Nothing, ZipFile.Writer}
end

DiskRecorder() = DiskRecorder(nothing)

ensure_initialized!(recorder::DiskRecorder, datum) =
    if recorder.file === nothing 
        @assert datum.exec_folder !== nothing
        dir = "$(datum.exec_folder)/round=$(datum.round)/samples" 
        mkpath(dir) 
        path = "$dir/replica=$(datum.replica.replica_index).jls.zip" 
        recorder.file = ZipFile.Writer(path)
    end

function record!(recorder::DiskRecorder, datum)
    ensure_initialized!(recorder, datum) 
    zip_internal_file = ZipFile.addfile(recorder.file, "$(datum.replica.chain)_$(datum.scan)", method=ZipFile.Deflate)
    serialize(zip_internal_file, datum.replica.state)
end

Base.empty!(recorder::DiskRecorder) = 
    if recorder.file !== nothing
        close(recorder.file)
        recorder.file = nothing
    end 

Base.merge(recorder1::DiskRecorder, recorder2::DiskRecorder) = DiskRecorder()

""" 
$SIGNATURES
"""
process_samples(processor::Function, pt::PT, round::Int, chain::Int) = 
    process_samples(processor, pt.exec_folder, round, chain) 

""" 
$SIGNATURES
"""
process_samples(processor::Function, pt::Result{PT}, round::Int, chain::Int) = 
    process_samples(processor, pt.exec_folder, round, chain) 

""" 
$SIGNATURES 

Process samples that were saved to disk using the `disk` recorder, at the 
given `round` and `chain`. 

Each sample is passed to the `processor` function, by calling 
`processor(scan_index, sample)` where `scan_index` is the iteration index 
within the round, starting at 1, and sample is the deserialized sample. 

This iterates over the samples in increasing `scan_index`. 
"""
function process_samples(processor::Function, exec_folder::String, round::Int, chain::Int) 
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
    samples_layout = Dict{Int, ZipFile.ReadableFile}()
    n_scans = 0
    for reader in values(readers)
        for zip_internal_file in reader.files 
            code = Base.split(zip_internal_file.name, '_')
            cur_chain = parse(Int, code[1])
            scan = parse(Int, code[2])
            if cur_chain == chain 
                @assert !haskey(samples_layout, scan)
                samples_layout[scan] = zip_internal_file
                n_scans = max(n_scans, scan)
            end
        end
    end

    for i in 1:n_scans 
        zip_internal_file = samples_layout[i] 
        sample = deserialize(zip_internal_file) 
        processor(i, sample)
    end

    # close readers
    close.(values(readers))

    return nothing
end

# TODO: document 

