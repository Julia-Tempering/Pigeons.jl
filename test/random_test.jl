using Pigeons
using Distributions
using BenchmarkTools

log_potential = (x) -> -logpdf(Normal(0.0, 1.0), x[1])
h = Pigeons.SliceSampler()
state = [0.3]

function main()
    # println(state)
    for i in 1:100
        Pigeons.slice_sample!(h, state, log_potential)
        # println(state)
    end
end

@btime main()