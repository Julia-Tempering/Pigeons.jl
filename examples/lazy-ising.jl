#=
Documenter.jl creates temporary modules with names like 
e.g. Main__atexample__named__deps.
So then when deserialization tries to resolve Main__atexample__named__deps.IsingLogPotential 
it crashes.

Using a LazyPotential addresses this issue.
=#
Pigeons.instantiate_target(::Val{:IsingLogPotential}) = IsingLogPotential(1.0, 2)