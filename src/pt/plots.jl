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

