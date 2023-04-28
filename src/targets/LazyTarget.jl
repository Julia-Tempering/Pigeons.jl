"""
Use when a target contains information that cannot 
be serialized, e.g. FFT plans 
(https://discourse.julialang.org/t/distributing-a-function-that-uses-fftw/69564)
so that the target is constructed just in time by each MPI node. 
"""
mutable struct LazyTarget{Flag, Actual}
    instance::Union{Actual, Nothing} 
    LazyTarget(Flag, Actual) = new{Flag, Actual}(nothing)
end

instantiate_target(::Type{Flag}) where {Flag} = @abstract 

## Example 
struct MyTargetFlag end 
instantiate_target(::Type{MyTargetFlag}) = toy_mvn_target(1)
# then use pigeons(target = LazyTarget(MyTargetFlag, typeof(toy_mvn_target(1))))

ensure_instantiated(lazy::LazyTarget{F, A}) where {F, A} =
    if lazy.instance === nothing 
        lazy.instance = instantiate_target(F)
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