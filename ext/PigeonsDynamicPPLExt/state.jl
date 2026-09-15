using DynamicPPL: AbstractPPL

# grouping of variables
function variables(vi::DynamicPPL.VarInfo, ::Type{T}) where {T}
    vns = keys(vi)
    # use Symbol instead of DynamicPPL.getsym.(vns) to avoid potential conflicts, see: https://github.com/Julia-Tempering/Pigeons.jl/pull/409#discussion_r2962749585
    syms = Symbol.(vns)
    return [sym for (sym, vn) in zip(syms, vns) if eltype(DynamicPPL.getindex_internal(vi, vn)) <: T]
end


Pigeons.continuous_variables(state::DynamicPPL.VarInfo) = variables(state::DynamicPPL.VarInfo, AbstractFloat)
Pigeons.discrete_variables(state::DynamicPPL.VarInfo) = variables(state::DynamicPPL.VarInfo, Integer)
function Pigeons.recorded_continuous_variables(vi::DynamicPPL.VarInfo)
    cvars = Pigeons.continuous_variables(vi)

    # allows us to handle samplers with adaptive preconditioners, which *may* be
    # used in fully cont models (no way of knowing here if they are actually used though)
    is_fully_continuous(vi) && push!(cvars, :singleton_variable)

    return cvars
end

# note: this returns unconstrained parameters when the varinfo is linked 
# (default in pigeons as of Jul-24), and constrained otherwise
Pigeons.variable(state::DynamicPPL.VarInfo, name::Symbol) =
    if name === :singleton_variable
        DynamicPPL.internal_values_as_vector(state)
    else
        vns = [vn for vn in keys(state) if Symbol(vn) === name]
        mapreduce(vn -> DynamicPPL.getindex_internal(state, vn), vcat, vns)
    end


function Pigeons.update_state!(vi::DynamicPPL.VarInfo, name::Symbol, index::Int, value)
    vns = [vn for vn in keys(vi) if Symbol(vn) === name]
    vn = vns[1]
    vals = DynamicPPL.getindex_internal(vi, vn)
    vals[index] = value
    return DynamicPPL.setindex_internal!!(vi, vals, vn)
end

# This is a replacement for `DynamicPPL.internal_values_as_vector` that avoids converting
# Integer-valued parameters to Float64. DynamicPPL's implementation of
# `internal_values_as_vector` uses `mapfoldl(..., vcat)` but because of Julia's type
# promotion rules, vcatting a `Vector{Float64}` and a `Vector{Int}` will result in a
# `Vector{Float64}` rather than the union of those two types (see e.g., `vcat([1.0], [2])`
# --> `[1.0, 2.0]`).
function vectorise_with_types(vi::DynamicPPL.VarInfo)
    result = Vector{Real}()
    for vn in keys(vi)
        append!(result, DynamicPPL.getindex_internal(vi, vn))
    end
    return map(identity, result) # Concretise if possible
end

function Pigeons.extract_sample(state::DynamicPPL.VarInfo, log_potential)
    invlink_vi = DynamicPPL.invlink(state, Pigeons.turing_model(log_potential))
    result = vectorise_with_types(invlink_vi)
    push!(result, log_potential(state))
    return result
end

function Pigeons.sample_names(state::DynamicPPL.VarInfo, log_potential)
    # Convert vectorised values in varinfo back to untransformed space
    model = Pigeons.turing_model(log_potential)
    accs = DynamicPPL.OnlyAccsVarInfo(DynamicPPL.RawValueAccumulator(false))
    init_strat = DynamicPPL.InitFromParams(DynamicPPL.get_values(state))
    _, accs = DynamicPPL.init!!(model, accs, init_strat, DynamicPPL.UnlinkAll())
    vnt = DynamicPPL.get_raw_values(accs)
    # Generate variable names based on the structure of each value
    result = VarName[]
    for (vn, val) in pairs(vnt)
        append!(result, AbstractPPL.varname_leaves(vn, val))
    end
    result = map(Symbol, result)
    push!(result, :log_density)
    return result
end

# explorer implementations
function Pigeons.slice_sample!(h::SliceSampler, vi::DynamicPPL.VarInfo, log_potential, cached_lp, replica)
    for vn in keys(vi)
        block = DynamicPPL.getindex_internal(vi, vn)
        cached_lp = Pigeons.slice_sample!(h, block, log_potential, cached_lp, replica)
    end
    return cached_lp
end

function Pigeons.step!(explorer::Pigeons.GradientBasedSampler, replica, shared, vi::DynamicPPL.VarInfo)
    vector_state = Pigeons.get_buffer(replica.recorders.buffers, :flattened_vi, get_dimension(vi))
    flatten!(vi, vector_state)
    Pigeons.step!(explorer, replica, shared, vector_state)
    # replica.state = DynamicPPL.unflatten!!(vi, vector_state) will assign a reconstructed vi object to replica.state
    i = firstindex(vector_state)
    for vn in keys(vi)
        block = DynamicPPL.getindex_internal(vi, vn)
        n = length(block)
        copyto!(block, firstindex(block), vector_state, i, n)
        i += n
    end
    replica.state = vi
end

# specialized equality checks
function Pigeons._recursive_equal(a::DynamicPPL.VarInfo, b::DynamicPPL.VarInfo)
    ka = keys(a)
    kb = keys(b)
    if length(ka) != length(kb)
        return false
    end
    for (vn_a, vn_b) in zip(ka, kb)
        if vn_a != vn_b || DynamicPPL.getindex_internal(a, vn_a) != DynamicPPL.getindex_internal(b, vn_b)
            return false
        end
    end
    return true
end


Pigeons.recursive_equal(
    a::Union{TuringLogPotential, DynamicPPL.Model, DynamicPPL.LogDensityFunction},
    b) = Pigeons._recursive_equal(a, b)
