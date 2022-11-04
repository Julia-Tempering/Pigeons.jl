function lognormalizingconstant(Energies, Schedule)
    n, N = size(Energies)
    Δβ = Schedule[2:end] .- Schedule[1:end-1]
    μ = mean(Energies, dims = 1)[2:end]
    sum(Δβ.*μ)
end