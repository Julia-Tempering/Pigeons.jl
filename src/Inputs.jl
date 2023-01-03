@kwdef struct Inputs{I}
    inference_problem::I
    rng::SplittableRandom = SplittableRandom(1)
    n_rounds::Int = 10
end

initial_n_chains(inputs::Inputs) = 10