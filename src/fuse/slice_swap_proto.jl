using ForwardDiff
using LinearAlgebra

function T(v) 
    x, u1, u2 = v 
    [y(v), u1 * f(x) / f(y(v)), (x-L(h(v)))/W(h(v))]
end

function F(v)
    x, u1, u2 = v 
    return [x, u2, u1]
end

function T(n::Int) 
    if n == 1
        return T
    else
        T_nm1 = T(n-1)
        return T_nm1 ∘ F ∘ T_nm1
    end
end

function pi(v)
    x, u1, u2 = v
    @assert 0.0 ≤ u1 ≤ 1.0
    @assert 0.0 ≤ u2 ≤ 1.0
    return f(x)
end

function h(v)
    x, u1, u2 = v 
    f(x) * u1
end

function y(v)
    x, u1, u2 = v
    L(h(v)) + u2 * W(h(v))
end

jacob(v, fct) = abs(det(ForwardDiff.jacobian(fct, v)))

ratio(v, fct) = pi(fct(v)) / pi(v) * jacob(v, fct)

f(x) = 1 - x^2

L(h) = -sqrt(1-h)

W(h) = 2*sqrt(1-h)

@show v = [0.1, 0.2, 0.5]

# check it is involutive 

for n in 1:5

    @show n

    fct = T(n)

    @show fct(fct(v))

    @show jacob(v, fct)

    @show ratio(v, fct)

end

nothing