

"""
$SIGNATURES 

`pt_arguments` can be either an [`Inputs`](@ref), to start 
a new Parallel Tempering algorithm, or a string pointing to 
an execution to resume. 
"""
pigeons(pt_arguments; submission = InCurrentProcess()) = pigeons(pt_arguments, submission)

"""
$SIGNATURES 

Passes the `args...` to [`Inputs`](@ref) and start 
a new Parallel Tempering algorithm with that inputs. 
"""
pigeons(; submission = InCurrentProcess(), args...) = 
    pigeons(Inputs(; args...), submission)

pigeons(pt_arguments, ::InCurrentProcess) = pigeons(PT(pt_arguments))


