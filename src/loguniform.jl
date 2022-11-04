function logpdf_LogUniform(a, b, d, x)
    if (x < d^a) | (x > d^b)
        out = -Inf
    else
        out = -log(b - a) - log(x) - log(log(d))
    end
    return out
end

rand_LogUniform(a, b, d) = d^rand(Uniform(a, b))