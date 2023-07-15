
import Pigeons: Immutable, serialize_immutables, 
                deserialize_immutables!

data_serialization_name = tempname()
fake_serialization_name = tempname()

struct Fake
    data1::Immutable{Vector{Int}}
    data2::Immutable{Vector{Int}}
    data3::Immutable{Vector{String}}
end

function test_serialize()
    ints = [1,2,3]
    strings = ["asdf", "a"]
    fake = Fake(Immutable(ints), Immutable(ints), Immutable(strings))
    
    serialize(fake_serialization_name, fake)
    serialize_immutables(data_serialization_name)
    Pigeons.flush_immutables!()
    return fake
end

@testset "Serialization" begin
    before = test_serialize()

    error_thrown = false
    try
        deserialize(fake_serialization_name)
    catch e
        error_thrown = true
    end
    @test error_thrown

    deserialize_immutables!(data_serialization_name)
    println(Pigeons.immutables)

    after = deserialize(fake_serialization_name)
    @test string(before) == string(after)
end 

