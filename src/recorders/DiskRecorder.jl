mutable struct DiskRecorder
    file::Union{Nothing, JLD2.JLDFile{JLD2.MmapIO}}
    group::Union{Nothing, JLD2.Group}

    "For a given (chain index, scan index), which replica JLD file holds this sample?"
    samples_layout::Dict{Pair{Int, Int}, Int}
end

DiskRecorder() = DiskRecorder(nothing, nothing, Dict{Pair{Int, Int}, Int}())

ensure_initialized!(recorder::DiskRecorder, datum) =
    if recorder.file === nothing 
        @assert datum.exec_folder !== nothing
        dir = "$(datum.exec_folder)/round=$(datum.round)/samples" 
        mkpath(dir) 
        file = "$dir/replica=$(datum.replica.replica_index).jld2" 
        recorder.file = jldopen(file, "w") 
        recorder.group = JLD2.Group(recorder.file, "samples") 
    end

function record!(recorder::DiskRecorder, datum)
    ensure_initialized!(recorder, datum) 
    recorder.group["$(datum.replica.chain)/$(datum.scan)"] = datum.replica.state 
    recorder.samples_layout[datum.replica.chain => datum.scan] = datum.replica.replica_index
end

Base.empty!(recorder::DiskRecorder) = 
    if recorder.file !== nothing
        close(recorder.file)
        recorder.file = nothing
        recorder.group = nothing
        empty!(recorder.samples_layout) 
    end 

Base.merge(recorder1::DiskRecorder, recorder2::DiskRecorder) =
    DiskRecorder(
            nothing, nothing, 
            merge(
                recorder1.samples_layout,
                recorder2.samples_layout)) 

# Immutable ..

function process_samples(processor, exec_folder, round::Int, chain::Int) 
    # open files 



    # close files
end



# TODO: document 

# TODO: avoid having to do checkpoint too