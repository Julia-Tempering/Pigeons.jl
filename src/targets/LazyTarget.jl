"""
Use when a target contains information that cannot 
be serialized, e.g. FFT plans 
(https://discourse.julialang.org/t/distributing-a-function-that-uses-fftw/69564)
so that the target is constructed just in time by each MPI node. 

```
# in a script.jl:
struct MyTargetFlag end 
import Pigeons.instantiate_target
Pigeons.instantiate_target(flag::MyTargetFlag) = toy_mvn_target(1)

# to run
pigeons(target = Pigeons.LazyTarget(MyTargetFlag(), on = ChildProcess(dependencies = ["script.jl"]))
```

Note: should only be used in the context of ChildProcess() / MPI() 
as it assumes that a single call to pigeons() will be made in the 
lifetime of the process. 
"""
struct LazyTarget{FlagType}
    flag::FlagType
end

# Note: we keep that in a global rather than in the LazyTarget 
# b/c we dont want type info of the product to leak into the 
# serialization; leading it untyped fails too at serialization time
const _lazy_singleton_cache = Dict{Any, Any}()

instantiate_target(flag) = @abstract 

function get_lazy_singleton(lazy) 
    if !haskey(_lazy_singleton_cache, lazy.flag)
        _lazy_singleton_cache[lazy.flag] = instantiate_target(lazy.flag)
    end
    return _lazy_singleton_cache[lazy.flag]
end

create_state_initializer(lazy::LazyTarget, inputs::Inputs) =
    create_state_initializer(get_lazy_singleton(lazy), inputs)

default_explorer(lazy::LazyTarget) =
    default_explorer(get_lazy_singleton(lazy))

create_reference_log_potential(lazy::LazyTarget, inputs::Inputs) =
    create_reference_log_potential(get_lazy_singleton(lazy), inputs)

create_path(lazy::LazyTarget, inputs::Inputs) =
    create_path(get_lazy_singleton(lazy), inputs)
