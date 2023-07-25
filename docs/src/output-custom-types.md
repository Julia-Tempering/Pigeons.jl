```@meta
CurrentModule = Pigeons
```

# Output for custom types

The [`sample_array`](@ref) function assumes that the variables are real or integer (the latter coerced into the former) 
and "flattened" into a uniform array. 

Custom types may not have this format. In that case, use [`get_sample`](@ref) instead:

```@example getsample
using Pigeons 

pt = pigeons(
        target = toy_mvn_target(10), 
        record = [traces])

vector = get_sample(pt)

length(vector) # = number of iterations = 2^10
```

Another option is to use [off-memory processing](@ref output-off-memory) which makes no assumption 
either on the type of each individual sample.