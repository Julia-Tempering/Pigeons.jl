import Pigeons
using DynamicPPL


@model function mix_dis_cts_model()
    α ~ Beta(1, 2)
    β ~ Beta(2, 3)
    n ~ Poisson(3.0) + 1
    y ~ Binomial(n, α * β)
end

rng = SplittableRandom(1)
model = mix_dis_cts_model()
vi = DynamicPPL.VarInfo(model)


@testset "variables" begin
    vars_of_Float64 = Pigeons.continuous_variables(vi)
    println("variables(vi, Float64) = ", vars_of_Float64)
    @test length(vars_of_Float64) == 2 # α, β
    vars_of_int = Pigeons.discrete_variables(vi)
    println("variables(vi, Int64) = ", vars_of_int)
    @test length(vars_of_int) == 2 # n, y


    syms = DynamicPPL.getsym.(keys(vi))
    var_values = Pigeons.variable(vi, :singleton_variable)
    println("Pigeons.variable() with no symbol specified: ", var_values)
    value_at_1 = Pigeons.variable(vi, syms[1])
    println("Pigeons.variable() with symbol specified : ", value_at_1)
    @test only(value_at_1) == var_values[1]
end

@testset "update_state!" begin
    syms = Symbol.(keys(vi))
    updated_vi = Pigeons.update_state!(vi, syms[1], 1, 0.81)
    @test DynamicPPL.internal_values_as_vector(updated_vi)[1] == 0.81
end


@testset "samples" begin
    # test extract_sample
    lp = TuringLogPotential(model)
    extracted_sample_values = Pigeons.extract_sample(vi, lp)
    # test sample_names
    extracted_sample_names = Pigeons.sample_names(vi, lp)
    @test length(extracted_sample_values) == length(extracted_sample_names)

end


@testset "equality" begin
    rng = SplittableRandom(1)
    @model function model_1(y)
        p ~ Beta(1, 2)
        y .~ Binomial(10, p)
        return nothing
    end
    @model function model_2(y)
        α ~ Beta(1, 2)
        β ~ Beta(2, 3)
        y .~ Binomial(10, α * β)
        return nothing
    end
    dist = Binomial(10, 0.2)
    y = rand(rng, dist, 1000)
    vi_1 = DynamicPPL.VarInfo(rng, model_1(y))
    vi_2 = DynamicPPL.VarInfo(rng, model_2(y))
    vi_1_copy = vi_1

    @test Pigeons.recursive_equal(vi_1, vi_2) == false
    @test Pigeons.recursive_equal(vi_1, vi_1_copy) == true
    @test Pigeons._recursive_equal(vi_1, vi_2) == false
    @test Pigeons._recursive_equal(vi_1, vi_1_copy) == true
    @test Pigeons.recursive_equal(model_1(y), model_2(y)) == false
    @test Pigeons.recursive_equal(model_1(y), model_1(y)) == true
    @test Pigeons.recursive_equal(TuringLogPotential(model_1(y)),TuringLogPotential(model_1(y))) == true
    @test Pigeons.recursive_equal(model_1(y), model_2(y)) == false
    @test Pigeons.recursive_equal(TuringLogPotential(model_1(y)), TuringLogPotential(model_2(y))) == false

end


@testset "invariance test" begin
    @model function gaussian_model()
        x ~ Normal(0, 1)
    end
    model = gaussian_model()
    res = Pigeons.invariance_test(TuringLogPotential(model), SliceSampler(), rng)
    println("res = ", res)
    @show res.pvalues
    @test res.passed

end


@testset "explorer" begin
    rng = SplittableRandom(1)
    @model function cont_model(y)
        x ~ Normal(0, 1)
        y .~ Normal(x, 1)
    end
    dist = Normal(0.7, 1.0)
    y = rand(rng, dist, 1000)
    model = cont_model(y)

    vi = DynamicPPL.VarInfo(rng, model, DynamicPPL.InitFromPrior(), DynamicPPL.LinkAll())

    log_potential = TuringLogPotential(model)
    h = SliceSampler()
    cached_lp = -Inf
    n = 100
    states = Vector{Float64}(undef, n)
    for i in 1:n
        replica = Pigeons.Replica(vi, 1, rng, (;), 1)
        cached_lp = Pigeons.slice_sample!(h, vi, log_potential, cached_lp, replica)
        inv_vi = DynamicPPL.invlink(vi, model)
        state = DynamicPPL.internal_values_as_vector(inv_vi)[1]
        states[i] = state
    end
    @test abs(mean(states) - 0.7) < 0.1
end

