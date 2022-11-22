"""
Store summary output from PT

Struct that contains summary obtained output after running PT.
For continuous *and* discrete variables, the mean and variance from the 
target chain are stored.
TODO: Choose more appropriate summary statistics or discrete variables.
"""
struct Summary{T<:AbstractVector}
    means::T
    vars::T
    n_samples::Int
    # function Summary(means::T, vars::T, n_samples::Int) where T<:AbstractVector
    #     @assert n_samples == length(means) == length(vars)
    #     return new(means, vars, n_samples)
    # end
end
# Summary(means::T, vars::T) where T<:AbstractVector = Summary(means, vars, length(means))


"""
Print `Summary` structs

Neatly prints the summary statistics for each variable after running PT. 
`s` is a `Summary` struct.
TODO: Make this output much nicer :)
"""
function print(s::Summary)
    println("          | mean | variance")
    println("---------------------------")
    for i in s.n_samples
        println("variable ", i, "|", s.means[i], "|", s.vars[i])
    end
end