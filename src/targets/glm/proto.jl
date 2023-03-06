non_linearity(x) = log1pexp(x) # for now, just the normalizer, rest is much easier

@concrete struct CachedParameters
    n::Int
    p::Int
    caches # p + n
    data   # stored as n x p
end 

Random.seed!(3);

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
    result = 0.0 
    for i in 1:n
        sum = 0.0
        for j in 1:p
            sum += transposed_design[i, j] * vector[j]
        end
        result += non_linearity(sum)
    end
    return result
end

function bench_fixtures(n, p)
    design = rand(p, n)
    transp = copy(transpose(design))
    params = rand(p) 
    return design, transp, params
end

n = 170
p = 210
design, transp, params = bench_fixtures(n, p)
cp = CachedParameters(design, params)

# non_linearity(design[1,1]*params[1]) + non_linearity(design[1,2] * params[1])


println("proto1 = $(value(cp))")

function bench(n, p)
    design, transp, params = bench_fixtures(n, p)

    t1 = @timed value_direct = direct(transp, params)
    cached = CachedParameters(design, params)
    t2 = @timed begin
        for j in 1:p 
            update(cached, j, params[j])
        end
    end

    @assert value_direct ≈ value(cached)

    return t1.time / (t2.time/p)
end

# quick viz using heatmap(log10.(Pigeons.speedups_matrix(13, 13)))
# rows are increasing n, columns, increasing p
function speedups_matrix(x, y)
    speedups = zeros(x, y)
    for i in 1:x
        for j in 1:y
            n = 2^i 
            p = 2^j 
            speedups[i, j] = bench(n, p)
        end
    end
    speedups
end
