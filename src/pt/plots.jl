"""
```@example 
using Pigeons
using Plots 
pt = pigeons(
        target = toy_mvn_target(1), 
        recorder_builders = [index_process], 
        n_rounds = 5)
plot(pt.reduced_recorders.index_process)
```
"""
@recipe function plot_index_process(index_process::Dict{Int, Vector{Int}})
    xlabel --> "iteration"
    ylabel --> "chain" 
    legend := false 
    for i in eachindex(index_process)
        @series index_process[i] 
    end
    return nothing
end

""" 
```@example 
using Pigeons
using Plots 
pt = pigeons(target = toy_mvn_target(1))
plot(pt.shared.tempering.communication_barriers.localbarrier)
```
"""
@recipe function plot_local_barrier(barrier::LocalBarrier)
    xlabel --> "β"
    ylabel --> "λ(β)" 
    legend := false 
    x = range(0.0, 1.0, length=100)
    y = barrier.(x)
    return x, y
end  

"""
```@example 
using Pigeons
using Plots 
pt = pigeons(
        target = Pigeons.bivariate_normal(1.0, 1.0, 0.99), 
        explorer = Pigeons.HMC())
plot(pt.explorer)
```
"""
@recipe function plot_hmc_adapt(hmc::HMC) 
    xlabel --> "β"
    ylabel --> "constant x ϵ(β)"
    legend := false
    x = range(0.0, 1.0, length=100)
    y = step_size_scalings(hmc.interpolated_curvatures, x)
    return x, y
end

