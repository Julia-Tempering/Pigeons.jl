using Pigeons
using Serialization
using Test

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
    serialize_immutables(data_serialization_name)
    serialize(fake_serialization_name, fake)
    empty!(Pigeons.immutables)
    return fake
end

before = test_serialize()

error_thrown = false
try
    deserialize(fake_serialization_name)
catch e
    global error_thrown = true
end
@assert error_thrown


deserialize_immutables!(data_serialization_name)

println(Pigeons.immutables)

after = deserialize(fake_serialization_name)

@assert string(before) == string(after)