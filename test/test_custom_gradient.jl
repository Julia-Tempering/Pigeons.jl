struct CustomGradientLogPotential
    precision::Float64
    dim::Int
end
function (log_potential::CustomGradientLogPotential)(x)
    -0.5 * log_potential.precision * sum(abs2, x)
end

Pigeons.initialization(lp::CustomGradientLogPotential, ::AbstractRNG, ::Int) = zeros(lp.dim)

LogDensityProblems.dimension(lp::CustomGradientLogPotential) = lp.dim
LogDensityProblems.logdensity(lp::CustomGradientLogPotential, x) = lp(x)

LogDensityProblemsAD.ADgradient(::ADTypes.AbstractADType, log_potential::CustomGradientLogPotential, replica::Pigeons.Replica) =
    Pigeons.BufferedAD(log_potential, replica.recorders.buffers)

const check_custom_grad_called = Ref(false)

function LogDensityProblems.logdensity_and_gradient(log_potential::Pigeons.BufferedAD{CustomGradientLogPotential}, x)
    logdens = log_potential.enclosed(x)
    global check_custom_grad_called[] = true
    log_potential.buffer .= -log_potential.enclosed.precision .* x
    return logdens, log_potential.buffer
end

@testset "Custom-gradient" begin
    pigeons(
        target = CustomGradientLogPotential(2.1, 4), 
        reference = CustomGradientLogPotential(1.1, 4), 
        n_chains = 1,
        explorer = AutoMALA())

    @assert check_custom_grad_called[]
end