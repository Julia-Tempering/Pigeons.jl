@testset "Examples directory" begin
    # make sure the examples run correctly
    include("../examples/custom-path.jl")
    include("../examples/general-target.jl")
    include("../examples/general-reference.jl")
    include("../examples/custom-sampler.jl")
    include("../examples/pluto-demo.jl")
    include("../examples/turing-galaxy.jl")
end