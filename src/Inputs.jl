@kwdef struct Inputs{I}
    inference_problem::I
    rng::SplittableRandom = SplittableRandom(1)
    n_rounds::Int = 10
    n_chains::Int = 10 # TODO: make Union{Nothing,..}, adapt it
end

