@testset "Examples directory" begin
    # make sure the examples run correctly
    include("../examples/custom-path.jl")
    include("../examples/general-target.jl")
    include("../examples/general-reference.jl")
end