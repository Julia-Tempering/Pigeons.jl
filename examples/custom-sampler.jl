include("ising.jl")



# perform sampling - sanity check: log(Z) ≈ true value of around 33.3 for this example
pt = pigeons(target = IsingLogPotential(1.0, 5))

# # sanity check: the local communication barrier has a peak near the predicted phase transition log(1+sqrt(2))/2
# using Plots
# plot(pt.shared.tempering.communication_barriers.localbarrier)