@kwdef struct Inputs{I}
    inference_problem::I
    rng::SplittableRandom = SplittableRandom(1)
    n_rounds::Int = 10
    min_n_chains::Int = 10
    recorder_builders::Vector{Function} = Function[]
end

