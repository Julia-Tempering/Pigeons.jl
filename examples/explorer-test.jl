include("comrade-interface.jl")

using SplittableRandoms
using Plots
rng = SplittableRandom(1)


logp = comrade_target_example()
#Pigeons.Pigeons.ScaledPrecisionNormalLogPotential(1.0, 10) #

state = #zeros(10)
[
    0.29949544751832907
    -0.47786489256752973
    -1.1094748964162686
    -0.46032550505418707
     3.2130072014872524
    -4.16147036442219
     2.2844873561764594
    -0.8851581866440199
    -0.7935568760334413
    -0.39248098656117464
]



dim = length(state)

momentum = randn(rng, dim)
target_std_deviations = ones(dim)
gradient_buffer = zeros(dim)

# check behaviour of V(X)


xs = []
for i in 1:50000
    
    push!(xs, logp(state))

    Pigeons.leaf_frog!(
        logp, 
        target_std_deviations, 
        state, momentum, 0.00005,
        gradient_buffer)  

end

plot(xs)

momentum = randn(rng, dim)

xs = []
for i in 1:50000
    
    push!(xs, logp(state))

    Pigeons.leaf_frog!(
        logp, 
        target_std_deviations, 
        state, momentum, 0.00005,
        gradient_buffer)  

end

plot!(xs)



# ### debug...

# @show state
# step_size = 1.0
# Pigeons.leaf_frog!(
#         logp, 
#         target_std_deviations, 
#         state, momentum, step_size,
#         gradient_buffer) 

# @show

# momentum .*= -1.0
# Pigeons.leaf_frog!(
#     logp, 
#     target_std_deviations, 
#     state, momentum, step_size,
#     gradient_buffer)   
    
# @show state

# println("---")

# ###

# println("before: $(Pigeons.hamiltonian(logp, state, momentum))")

# obj1 = Pigeons.adaptive_leap_frog_objective(
#     logp, 
#     target_std_deviations, 
#     state, momentum, 
#     gradient_buffer)

# p = plot(obj1, 0.0:0.0001:0.012)

# step_size = Pigeons.adaptive_leap_frog!(
#     logp,
#     target_std_deviations, 
#     state, momentum, 
#     gradient_buffer)

# @show step_size
# println()

# momentum .*= -1.0

# obj2 = Pigeons.adaptive_leap_frog_objective(
#     logp, 
#     target_std_deviations, 
#     state, momentum, 
#     gradient_buffer)

# @show obj2(step_size)

# p = plot!(obj2)

# step_size2 = Pigeons.adaptive_leap_frog!(
#     logp,
#     target_std_deviations, 
#     state, momentum, 
#     gradient_buffer)

# @show step_size2

# @show state


# return p

# state = Pigeons.initialization(logp, rng, -1)
# obj2 = Pigeons.adaptive_leap_frog_objective(
#     logp, 
#     target_std_deviations, 
#     state, momentum, 
#     gradient_buffer)


# plot!(obj2)

# momentum = randn(rng, dim)
# obj3 = Pigeons.adaptive_leap_frog_objective(
#     logp, 
#     target_std_deviations, 
#     state, momentum, 
#     gradient_buffer)

# plot!(obj3)


#=

Some ideas:

- to get some insight on dynamic implicit epsilon, plot the target ratio



- Hit and run?
- Discrete BPS? <--- might be 


Init thing:
https://github.com/stan-dev/stan/blob/develop/src/stan/mcmc/hmc/base_hmc.hpp


Just use existing? But tricky in PT context

https://github.com/tpapp/DynamicHMC.jl/blob/master/test/test_diagnostics.jl
https://github.com/TuringLang/AdvancedHMC.jl/blob/master/src/adaptation/stepsize.jl




New plan

- 


=#