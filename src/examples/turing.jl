# Unconditioned coinflip model with `N` observations.
@model function coinflip(; N::Int)
    p ~ Beta(1, 12)
    y ~ filldist(Bernoulli(p), N)
    return y
end;
coinflip(y::AbstractVector{<:Real}) = coinflip(; N=length(y)) | (; y)

# *Unidentifiable* unconditioned coinflip model with `N` observations.
@model function coinflip_unidentifiable(; N::Int)
    p1 ~ Uniform(0, 1)
    p2 ~ Uniform(0, 1)
    y ~ filldist(Bernoulli(p1*p2), N)
    return y
end;
coinflip_unidentifiable(y::AbstractVector{<:Real}) = coinflip_unidentifiable(; N=length(y)) | (; y)

function flip_model()
    p_true = 0.5;
    N = 100;
    data = rand(Bernoulli(p_true), N);
    return coinflip(data)
end

function flip_model_unidentifiable()
    p_true = 0.5;
    N = 100;
    data = rand(Bernoulli(p_true), N);
    return coinflip_unidentifiable(data)
end