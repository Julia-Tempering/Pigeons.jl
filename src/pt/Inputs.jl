@kwdef mutable struct Inputs{I}
    inference_problem::I
    rng::SplittableRandom = SplittableRandom(1)
    n_rounds::Int = 10
    n_chains::Int = 10
    recorder_builders::Vector{Function} = Function[]
end

