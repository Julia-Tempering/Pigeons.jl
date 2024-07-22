#=
Analytic log-normalization function for the toy unidentifiable model

p1 ~ U(0,1)
p2 ~ U(0,1)
y|p1,p2 ~ Binomial(n,p1*p2)

Let u:=p1p2. Then

F(u) = P(U<= u) = P(p1p2 <= u)
= int_0^1 dp1 int_0^1 dp2 1{p1 <= u/p2}
= int_0^1 dp1 int_0^min{1, u/p2} dp2
= int_0^1 dp1 min{1, u/p2}
= int_0^u dp1 + int_u^1 dp1 u/p2
= u - ulog(u)

Hence

f(u) = dF/du = 1 - log(u) - 1 = -log(u)

Then for all b in [0,1], the normalization constant is

p_b(y) = E_prior[Binom(y;p1p2,n)^b] = E_u[Binom(y;u,n)^b]
= (n choose y)^b int du [-log(u)] u^{yb} (1-u)^{b(n-y)}
= (n choose y)^b Beta(by+1, b(n-y)+1) [1/Beta(by+1, b(n-y)+1)] int du [-log(u)] u^{yb} (1-u)^{b(n-y)}
= (n choose y)^b Beta(by+1, b(n-y)+1) E_{u~Beta(by+1, b(n-y)+1)}[-log(u)] 
= (n choose y)^b Beta(by+1, b(n-y)+1) (ψ(bn+2)-ψ(by+1))

Hence

log(p_b(y)) = b*logbinom(n,y) + logbeta(by+1,b(n-y)+1) + log(ψ(bn+2)-ψ(by+1))

Note that when either b=0 or n=k=0, the above is 0.
=#

using SpecialFunctions

unid_target_exact_logZ(n, y, beta=1) = beta*first(logabsbinomial(n,y)) + 
    logbeta(beta*y+1,beta*(n-y)+1) + log(digamma(beta*n+2) - digamma(beta*y+1))

unid_target_exact_logZ(target::TuringLogPotential, args...) = 
    unid_target_exact_logZ(target.model.args..., args...)
