```@meta
CurrentModule = Pigeons
```

# [Manipulating the output of pigeons](@id output-overview)

Pigeons supports several methods to post-process the output
of parallel tempering, including [convenient methods that 
store in memory all the samples](@ref output-numerical), 
as well as memory efficient 
methods using either [the disk](@ref output-off-memory) or 
[constant-memory statistics](@ref output-online). 

- [Interpreting pigeons' standard output](@ref output-reports)
- [Working with traces](@ref output-traces)
- [Creating plots.](@ref output-plotting)
- [Approximation of the normalization constant.](@ref output-normalization)
- [Numerical summaries and diagnostics.](@ref output-numerical)
- [Online (constant-memory) statistics.](@ref output-online)
- [Off-memory processing.](@ref output-off-memory)
- [PT-specific diagnostics.](@ref output-pt)
- [Post-processing for MPI runs.](@ref output-mpi-postprocessing)
- [Output for custom types.](@ref output-custom-types)
- [Extended output, i.e. including non-target chains](@ref output-extended)
- [Further customization using "recorders".](@ref collecting-statistics)