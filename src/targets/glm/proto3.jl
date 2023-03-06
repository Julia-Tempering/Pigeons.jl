

#=

Construct: ordered list of...

node_name(i) = 
    combine(op, range(i)) do i, j, access_to_other_nodes
        [some calculation]
    end

Here i, j could be tuple, but still ordered.
Need to determine what is dynamic and static dependencies 
    could be done when invoking access_to_other_nodes

For the dynamic ones, need to flesh things out a bit 
    more...

Operations:
- initial pass 
- updates 

=#

struct Variable{name} # TODO: Variable{model, name} to handle having same name in two models 
    Variable(name::Symbol) = new{name}()
end
name(::Variable{n}) where {n} = n

#=
From the user point of view, state objects (i.e. cache, buffer) 
behave like NamedTuple

Under the hood, we add behaviour to be able to record, replay and reset what was 
accessed (should all be done without allocation)

assume things are static until proven otherwise
=#

# assumes buffer is preprocessed
# assumes virtual_indices have already been sorted (if needed)
function update(variable::Variable{name}, virtual_indices, cache, buffer) where {name}
    op = operation(variable)
    inv = inverse_operation(variable)
    array_to_update = getfield(cache, name)
    for virtual_index in virtual_indices
        old_value = evaluate(variable, virtual_index, buffer)
        new_value = evaluate(variable, virtual_index, cache)
        # later:
        # update_links!(variable, virtual_index, cache, buffer) 
        delta = inv(new_value, old_value) 
        #println("$variable, $old_value, $new_value, $delta, $cache, $buffer")
        concrete_index = concrete(variable, virtual_index)
        array_to_update[concrete_index] = op(array_to_update[concrete_index], delta) 
    end
end

function initialize(variable::Variable{name}, virtual_indices, cache) where {name}
    op = operation(variable)
    array_to_update = getfield(cache, name)
    for virtual_index in virtual_indices
        new_value = evaluate(variable, virtual_index, cache)
        # later:
        # update_links!(variable, virtual_index, cache, buffer) 
        #println("$variable, $old_value, $new_value, $delta, $cache, $buffer")
        concrete_index = concrete(variable, virtual_index)
        array_to_update[concrete_index] = op(array_to_update[concrete_index], new_value) 
    end
end

function setup_buffer(variable::Variable{name}, virtual_indices, cache, buffer) where {name}
    destination = getfield(buffer, name)
    source = getfield(cache, name)
    for virtual_index in virtual_indices
        # TODO: inefficient (should loop over unique concretes) but won't be bottleneck - worth improving still for x2 speedup
        concrete_index = concrete(variable, virtual_index)
        destination[concrete_index] = source[concrete_index]
    end
end

concrete(variable, virtual_index) = virtual_index[1]
#evaluate(variable, virtual_index, state) = @abstract 
operation(variable) = +
inverse_operation(variable) = -
#identity_element(variable) = 0.0 

# demo

concrete(variable::Variable{:result}, virtual_index) = 1

function evaluate(variable::Variable{:dotprod}, virtual_index, state)
    return state.data[virtual_index[2], virtual_index[1]] * state.param[virtual_index[2]]
end

evaluate(variable::Variable{:result}, data_index, state) = 
    non_linearity(state.dotprod[data_index])

# NEXT: BABY STEP: REPLICATE essentially proto.jl, in a manual fashion, 
#                  to see how much slow down we suffer 

#= 

    TODOs:
        - implement orderings
        - add overhead = time for full pass / time for direct
        - replace @time by @benchmark
        - test!

=#

function init_state(data)
    p, n = size(design) 
    param = zeros(p) # Spied(zeros(p))
    dotprod = zeros(n) #Spied(zeros(n)) 
    result = zeros(1)
    return (; param, data, dotprod, result)
end

ns = 1:n

function proto3_update(cache, buffer, orderings, entry::Int, new_value)
    setup_buffer(Variable(:dotprod), orderings[entry], cache, buffer)
    setup_buffer(Variable(:result), ns, cache, buffer)
    cache.param[entry] = new_value
    update(Variable(:dotprod), orderings[entry], cache, buffer)
    update(Variable(:result), ns, cache, buffer) 
end

function proto3_initialize(cache, orderings)
    initialize(Variable(:dotprod), orderings[entry], cache)
    initialize(Variable(:result), 1:n, cache) 
end

function proto3_fixtures(data)
    p, n = size(design) 
    cache = init_state(data)
    buffer = init_state(data)
    orderings = compute_orderings(p, n)
    return cache, buffer, orderings
end

function compute_orderings(p, n)
    result = Vector{Vector{Tuple{Int64, Int64}}}()
    for cur_p in 1:p
        list = Vector{Tuple{Int64, Int64}}() 
        for cur_n in 1:n 
            push!(list, (cur_n, cur_p))
        end
        push!(result, list)
    end
    return result
end

cache, buffer, orderings_ = proto3_fixtures(design) 

proto3_initialize(cache, orderings_)

for cur_p in 1:p
    proto3_update(cache, buffer, orderings_, cur_p, params[cur_p])
end

println("proto3 = $(cache.result[1])")


# spied data structures

#=

ops:

- reset should be O(# unique things updates)

- 

=#

#===

@concrete struct Spied
    container 
    accessed
end

index_type(container_type) = keytype(container_type)
index_type(::Type{T}) where {T <: NamedTuple} = Symbol

Spied(container::T) where {T} = Spied(container, Set{index_type(T)})

#Spied(vector::AbstractVector) = Spied(vector, Set{Int}()) 
#Spied(named_tuple::NamedTuple) = Spied(named_tuple, Set{Symbol}())

reset!(s::Spied{C, A}) where {C <: AbstractArray} = empty!(s.accessed)
reset!(container) = nothing 
function reset(s::Spied{C, A}) where {C <: NamedTuple}
    for symb in s.accessed 
        reset!(container[symb])
    end
    empty!(s.accessed)
end

function Base.getindex(s::Spied, index)
    push!(s.accessed, index) 
    return getindex(s.container, index)
end

function Base.getproperty(s::Spied, symbol)
    push!(s.accessed)
    return getproperty(s.container, symbol)
end

===#