@kwdef struct Resume
    checkpoint_folder::String 
    n_rounds::Union{Int,Nothing}
end

struct Result{T}
    exec_folder::String 
end

@informal pigeons_output begin # ?
    # either PT or Result{PT}
end

# TODO ommitting rounds; support extra_rounds 
Resume(pt::PT, from_round::Int, to_round::Int) = TODO() 
Resume(result::Result, from_round::Int, to_round::Int) = TODO()

abstract type Submission end 
struct InCurrentProcess <: Submission end 

@kwdef struct ToNewProcess <: Submission  # used to control # of threads
    n_threads::Int 
end 

@concrete struct ToMPI end

pigeons(; submission = InCurrentProcess(), args...) = 
    pigeons(Inputs(args...), submission)

pigeons(pt_arguments) = pigeons(pt_arguments, InCurrentProcess())

function pigeons(inputs::Inputs, ::InCurrentProcess) 
    pt = PT(pt_arguments)
    run!(pt)
    return pt
end

function pigeons(resume::Resume, ::InCurrentProcess)
    pt = PT(resume.checkpoint_folder)
    pt.shared.inputs = resume.n_rounds 
    run!(pt)
    return pt 
end

function pigeons(pt_arguments, mpi_submission::ToMPI)
    # if pt_arguments is a Resume, use it to populate mpi_configuration
    # serialize pt_arguments
    # generate exec_folder
    # generate script; calls pigeons()
    # do job submission
    # return the exec_folder
end

function pigeons(pt_arguments, new_process::ToNewProcess)
    # run in child process, controlling the # of threads

    # for now, just load Pigeons, eventually, detect & save which 
    # modules should be loaded via 
    #    https://stackoverflow.com/questions/25575406/list-of-loaded-imported-packages-in-julia
    #    see filter((x) -> typeof(eval(x)) <:  Module && x ≠ :Main, names(Main,imported=true))
end


