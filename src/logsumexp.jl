function logsumexp!(out, a, b)
    n = length(out)
    for i in 1:n
        val = max(a[i], b[i])
        out[i] = val + log(exp(a[i] - val) + exp(b[i] - val))
    end
end
