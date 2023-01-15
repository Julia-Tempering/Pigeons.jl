"""
$SIGNATURES 

`pt_arguments` can be either an [`Inputs`](@ref), to start 
a new Parallel Tempering algorithm, or a string pointing to 
an execution to resume. 
"""
pigeons(pt_arguments; on = ThisProcess()) = pigeons(pt_arguments, on)

"""
$SIGNATURES 

Passes the `args...` to [`Inputs`](@ref) and start 
a new Parallel Tempering algorithm with that inputs. 
"""
pigeons(; on = ThisProcess(), args...) = 
    pigeons(Inputs(; args...), on)

pigeons(pt_arguments, ::ThisProcess) = pigeons(PT(pt_arguments))
