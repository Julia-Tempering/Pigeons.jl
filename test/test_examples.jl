@testset "Examples directory" begin
    # make sure the examples run correctly
    include("../examples/custom-path.jl")
    include("../examples/general-target.jl")
    include("../examples/general-reference.jl")
    
    # that does not seem to work... some dependency hell---need to switch to better Comrade integration method..
    # include("../examples/black-hole-imaging.jl")
    # include("../examples/jube-example.jl")
    # # load back the test env, otherwise we would be in the example env 
    # # could cause problem in some circumstances (MPI tests)
    # include("activate_test_env.jl")
end