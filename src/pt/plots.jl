"""
$SIGNATURES

A plot `@recipe` for an index process. 
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

@recipe function plot_local_barrier(barrier::LocalBarrier)
    xlabel --> "β"
    ylabel --> "λ(β)" 
    legend := false 
    x = range(0.0, 1.0, length=100)
    y = barrier.(x)
    return x, y
end  

# @recipe function plot_local_barrier(barrier::LocalBarrier)
#     return plot_barrier(barrier)
# end

# @recipe function plot_global_barrier(barrier::Interpolations.MonotonicInterpolation)
#     return plot_barrier(barrier)
# end
