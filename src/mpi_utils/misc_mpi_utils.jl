"""
$SIGNATURES

A flag is set by launch scripts (see ChildProcess.jl) to indicate 
if this process is a child MPI process under an mpiexec. 
Otherwise, that flag is false by default.

This function retrieves the value of that flag. 
""" 
mpi_active() = mpi_active_ref[]

const mpi_active_ref = Ref(false)

#=
Rationale for :funneled / threading model: 
    - all the swap logic is single threaded
    - multithreading occurs in exploration only
=#
init_mpi() = Init(threadlevel = :funneled)
