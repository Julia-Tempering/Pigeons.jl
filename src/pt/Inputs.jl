@kwdef mutable struct Inputs{I}
    target::I
    seed::Int = 1
    n_rounds::Int = 10
    n_chains::Int = 10
    checkpoint::Bool = true
    recorder_builders::Vector{Function} = Function[]
    checked_round::Int = 0
end

