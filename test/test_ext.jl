test_dir = @__DIR__ 
@assert basename(test_dir) == "test"

@testset "Without extensions" begin 
    without_script = abspath("$test_dir/supporting/without-extension.jl")
    run(`$(Pigeons.julia_cmd_no_start_up()) $without_script`)
end

@testset "With DynamicPPL extensions" begin 
    with_ppl_script = abspath("$test_dir/supporting/with-dynamicppl-extension.jl")
    run(`$(Pigeons.julia_cmd_no_start_up()) $with_ppl_script`)
end

