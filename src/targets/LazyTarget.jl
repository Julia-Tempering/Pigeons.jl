"""
Use when a target contains information that cannot 
be serialized, e.g. FFT plans 
(https://discourse.julialang.org/t/distributing-a-function-that-uses-fftw/69564)
so that the target is constructed just in time by each MPI node. 

```
struct MyTargetFlag end 
import Pigeons.instantiate_target
Pigeons.instantiate_target(flag::MyTargetFlag) = toy_mvn_target(1)
pigeons(target = Pigeons.LazyTarget(MyTargetFlag())
```
"""
mutable struct LazyTarget{FlagType, ActualType}
    flag::FlagType
    instance::Union{ActualType, Nothing} 
    LazyTarget(flag::FlagType) where {FlagType} = 
        new{FlagType, typeof(instantiate_target(flag))}(flag, nothing)
end

instantiate_target(flag) = @abstract 

ensure_instantiated(lazy) =
    if lazy.instance === nothing 
        lazy.instance = instantiate_target(lazy.flag)
    end

function create_state_initializer(lazy::LazyTarget, inputs::Inputs) 
    ensure_instantiated(lazy)
    create_state_initializer(lazy.instance, inputs)
end

function default_explorer(lazy::LazyTarget) 
    ensure_instantiated(lazy)
    default_explorer(lazy.instance)
end

function create_reference_log_potential(lazy::LazyTarget, inputs::Inputs) 
    ensure_instantiated(lazy)
    create_reference_log_potential(lazy.instance, inputs)
end

function create_path(lazy::LazyTarget, inputs::Inputs) 
    ensure_instantiated(lazy)
    create_path(lazy.instance, inputs)
end