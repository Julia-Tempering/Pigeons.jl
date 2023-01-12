struct Result{T}
    exec_folder::String 
end

pigeons(; submission = InCurrentProcess(), args...) = 
    pigeons(Inputs(; args...), submission)

"""
$SIGNATURES 

`pt_arguments` can be either an [`Inputs`](@ref), to start 
a new Parallel Tempering algorithm, or a string pointing to 
an execution to resume. 
"""
pigeons(pt_arguments) = pigeons(pt_arguments, InCurrentProcess())

pigeons(pt_arguments, ::InCurrentProcess) = pigeons(PT(pt_arguments))


