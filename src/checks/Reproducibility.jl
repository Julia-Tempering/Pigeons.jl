#= WIP =#

struct Violation
    field_path::Stack{Any}
    value1 
    value2
end

"""
Used to check reproducibility of jobs.  
Less emphasis on speed, more on getting diagnostic when 
reproducibility is violated.
"""
struct Reproducibility
    violations::Vector{Violation}
    _current_field_path::Stack{Any}
end
Reproducibility() = Reproducibility(Vector{Violation}(), Stack{Any}())

function reproduces(o1, o2) 
    result = Reproducibility()
    reproduces(result, o1, o2)
    return result
end

function reproduces(r::Reproducibility, o1::Vector{T}, o2::Vector{T}) where {T}
    if length(o1) != length(o2)
        add_violation(r, o1, o2)
    else
        for i in eachindex(o1)
            push!(r._current_field_path, i)
            reproduces(r, o1[i], o2[i])
            pop!(r._current_field_path)
        end
    end
end

function reproduces(r::Reproducibility, o1::Dict, o2::Dict)
    if keys(o1) != keys(o2)
        add_violation(r, o1, o2)
    else
        for (key, value) in o1
            push!(r._current_field_path, (key, value))
            reproduces(r, o1[key], o2[key])
            pop!(r._current_field_path)
        end
    end
end

function reproduces(r::Reproducibility, o1::T1, o2::T2) where {T1, T2}
    if T1 != T2
        add_violation(r, o1, o2)
    else
        fields1 = fieldnames(T1)
        fields2 = fieldnames(T2)
        if (fields1 != fields2)
            add_violation(r, o1, o2)
        else
            if isempty(fields1)
                if o1 != o2 
                    add_violation(r, o1, o2)
                end
            else
                for field in fields1
                    push!(r._current_field_path, field)
                    reproduces(r, getfield(o1, field), getfield(o2, field))
                    pop!(r._current_field_path)
                end
            end   
        end
    end
end

add_violation(r, o1, o2) = push!(r.violations, Violation(deepcopy(r._current_field_path), o1, o2))

function Base.show(io::IO, r::Reproducibility) 
    violations = join(r.violations, ", ")
    print(io, "Reproducibility($violations)")
end

function Base.show(io::IO, v::Violation)
    path = join(v.field_path, "<-")
    print(io, "Violation($path, $(v.value1), $(v.value2))")
end

function test()
    s1 = SplittableRandom(1)
    s2 = SplittableRandom(1)

    println(reproduces(s1, s2))
end
