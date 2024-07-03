# DynamicPPL ----------
Pigeons.continuous_variables(state::DynamicPPL.TypedVarInfo) = 
    push!(variables(state::DynamicPPL.TypedVarInfo, AbstractFloat), :singleton_variable) # adding :singleton_variable allows us to handle samplers with adaptive preconditioners
Pigeons.discrete_variables(state::DynamicPPL.TypedVarInfo) = variables(state::DynamicPPL.TypedVarInfo, Integer)

# note: this returns unconstrained parameters when the varinfo is linked 
# (default in pigeons as of Jul-24), and constrained otherwise
Pigeons.variable(state::DynamicPPL.TypedVarInfo, name::Symbol) = 
    if name === :singleton_variable
        DynamicPPL.getall(state)
    else
        state.metadata[name].vals
    end

function Pigeons.update_state!(state::DynamicPPL.TypedVarInfo, name::Symbol, index::Int, value)
    state.metadata[name].vals[index] = value
end
variables(vi::DynamicPPL.TypedVarInfo{<:NamedTuple{names}}, ::Type{T}) where {names,T} =
    [name for (name, meta) in zip(names, vi.metadata) if eltype(meta.vals) <: T]

# From Turing.jl/src/utilities/helper.jl
ind2sub(v, i) = Tuple(CartesianIndices(v)[i])


function Pigeons.extract_sample(state::DynamicPPL.TypedVarInfo, log_potential)
    DynamicPPL.invlink!!(state, Pigeons.turing_model(log_potential))
    result = DynamicPPL.getall(state)
    DynamicPPL.link!!(state, DynamicPPL.SampleFromPrior(), Pigeons.turing_model(log_potential))
    push!(result, log_potential(state))
    return result
end

function Pigeons.sample_names(state::DynamicPPL.TypedVarInfo, _)
    result = Symbol[]
    all_names = fieldnames(typeof(state.metadata))
    for var_name in all_names
        var = state.metadata[var_name].vals
        if var isa Number || (var isa AbstractArray && length(var) == 1)
            push!(result, var_name)
        elseif var isa AbstractArray
            # flatten vector names following Turing convention
            for i in eachindex(var)
                var_and_index_name =
                    Symbol(var_name, "[", join(ind2sub(size(var), i), ","), "]")
                push!(result, var_and_index_name)
            end
        else
            error("don't know how to handle var `$var_name` of type $(typeof(var))")
        end
    end
    push!(result, :log_density)
    return result
end

#=
explorer implementations
=#
function Pigeons.slice_sample!(h::SliceSampler, vi::DynamicPPL.TypedVarInfo, log_potential, cached_lp, replica)
    for meta in vi.metadata
        cached_lp = Pigeons.slice_sample!(h, meta.vals, log_potential, cached_lp, replica)
    end
    return cached_lp
end
function Pigeons.step!(explorer::Pigeons.HamiltonianSampler, replica, shared, vi::DynamicPPL.TypedVarInfo)
    vector_state = DynamicPPL.getall(vi)
    Pigeons.step!(explorer, replica, shared, vector_state)
    DynamicPPL.setall!(replica.state, vector_state)
end

#=
specialized equality checks
=#
Pigeons.recursive_equal(a::DynamicPPL.TypedVarInfo, b::DynamicPPL.TypedVarInfo) =
    # as of Nov 2023, DynamicPPL does not supply == for TypedVarInfo
    length(a.metadata) == length(b.metadata) &&
        sample_names(a,1) == sample_names(b,1) && # second argument is not used
        DynamicPPL.getall(a) == DynamicPPL.getall(b)
    

Pigeons.recursive_equal(
    a::Union{TuringLogPotential,DynamicPPL.Model,DynamicPPL.ConditionContext}, 
    b) = Pigeons._recursive_equal(a, b)
