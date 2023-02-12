non_linearity(x::Float64) = log(1.0 + exp(x)) # for now, just the normalizer, rest is much easier

@concrete struct CachedParameters
    n::Int
    p::Int
    caches # p + n
    data   # stored as n x p
end 

function CachedParameters(design::Matrix, params::Vector) 
    p, n = size(design)
    @assert length(params) == p 
    caches = zeros(p + n + 1)
    result = CachedParameters(n, p, caches, design)
    for j in 1:p 
        update(result, j, params[j])
    end
    return result
end

value(cached) = cached.caches[cached.p + cached.n + 1]

function update(cached, entry::Int, new_value)
    @assert 1 ≤ entry ≤ cached.p
    p = cached.p
    n = cached.n

    old_value = cached.caches[entry]
    cached.caches[entry] = new_value 

    result = 0.0
    for i in 1:n
        idx = p + i
        old_cache = cached.caches[idx]
        dot_product_delta = (new_value - old_value) * cached.data[entry, i]
        new_cache = old_cache + dot_product_delta
        result += non_linearity(new_cache)
        cached.caches[idx] = new_cache
    end
    cached.caches[p + n + 1] = result
end

function direct(transposed_design::Matrix, vector) 
    n = size(transposed_design, 1)
    p = size(transposed_design, 2)
    @assert length(vector) == p
    result::Float64 = 0.0 
    for i in 1:n
        sum::Float64 = 0.0
        for j in 1:p
            sum += transposed_design[i, j] * vector[j]
        end
        result += non_linearity(sum)
    end
    return result
end

function bench(n, p)
    # build a matrix 
    design = rand(p, n)
    transp = copy(transpose(design))
    params = rand(p) 

    @time value_direct = direct(transp, params)
    cached = CachedParameters(design, params)
    @time begin
        for j in 1:p 
            update(cached, j, params[j])
        end
    end
    
    println("$value_direct $(value(cached))")
end