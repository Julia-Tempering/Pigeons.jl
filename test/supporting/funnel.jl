using StatsFuns
using LogDensityProblems

struct NealFunnel
    dim::Int
    scale::Float64
end

function (log_potential::NealFunnel)(x)
    result = normlogpdf(0.0, 3.0, x[1])
    for i in 2:length(x)
        result += normlogpdf(0.0, exp(x[1]/log_potential.scale), x[i])
    end
    return result
end

LogDensityProblems.dimension(lp::NealFunnel) = lp.dim + 1
LogDensityProblems.logdensity(lp::NealFunnel, x) = lp(x)

Pigeons.initialization(funnel::NealFunnel, _, _) = zeros(funnel.dim + 1)