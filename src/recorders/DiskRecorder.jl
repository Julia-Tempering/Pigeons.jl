mutable struct DiskRecorder
    file::Union{Nothing, ZipFile.Writer}
end

DiskRecorder() = DiskRecorder(nothing)

ensure_initialized!(recorder::DiskRecorder, datum) =
    if recorder.file === nothing 
        @assert datum.pt.exec_folder !== nothing
        dir = "$(datum.pt.exec_folder)/round=$(datum.pt.shared.iterators.round)/samples" 
        mkpath(dir) 
        path = "$dir/replica=$(datum.replica.replica_index).jls.zip" 
        recorder.file = ZipFile.Writer(path)
    end

function record!(recorder::DiskRecorder, datum)
    ensure_initialized!(recorder, datum) 
    zip_internal_file = ZipFile.addfile(recorder.file, "$(datum.replica.chain)_$(datum.pt.shared.iterators.scan)", method=ZipFile.Deflate)
    log_potential = find_log_potential(datum.replica, datum.pt.shared.tempering, datum.pt.shared)
    extracted = extract_sample(datum.replica.state, log_potential)
    serialize(zip_internal_file, extracted)
end

Base.empty!(recorder::DiskRecorder) = 
    if recorder.file !== nothing
        close(recorder.file)
        recorder.file = nothing
    end 

Base.merge(recorder1::DiskRecorder, recorder2::DiskRecorder) = DiskRecorder()

