```@meta
CurrentModule = Pigeons
```

# [Saving traces](@id output-traces)

The `traces` refer to the list of samples ``X_1, X_2, \dots, X_n``
from which we can approximate expectations of the form 
``E[f(X)]``, where ``X \sim \pi`` via 
a Monte Carlo average of the form ``\sum_i f(X_i) / n``. 

To indicate that the traces should be saved, use

```@example record-traces
using Pigeons 

target = Pigeons.toy_turing_unid_target(100, 50)

pt = pigeons(;  target, 
                n_rounds = 3,
                # make sure to record the trace:
                record = [traces; round_trip; record_default()])
```

Note that there are more memory efficient alternatives 
to saving the full traces: see 
[online (constant-memory) statistics](@ref output-online) and
[off-memory processing.](@ref output-off-memory)


## Accessing traces 

Use [`get_sample`](@ref) to access the list of samples:

```@example record-traces
get_sample(pt)
```

In the special case where each state is a vector, use 
[`variable_names`](@ref) to obtain description of the 
vector components:

```@example record-traces
variable_names(pt)
```

Still in the special case where each state is a vector, 
it is often convenient to organize the result into a single 
array, this is done using [`sample_array`](@ref):

```@example record-traces
sample_array(pt)
```


## Customizing what is saved in the traces 

You may want to save only some statistics of interest, or a subset of the dimensions to 
take up less memory. 

We show here an example saving only the 
value of the log potential:

```@example record-traces
StateType = typeof(pt.replicas[1].state) 
LogPotentialType = typeof(pt.shared.tempering.log_potentials[1]) 

Pigeons.extract_sample(state::StateType, log_potential::LogPotentialType) = 
    log_potential(state)

pt = pigeons(;  target, 
                n_rounds = 3,
                # make sure to record the trace:
                record = [traces; round_trip; record_default()])

sample_array(pt)
```

For completeness, it is a good idea to also adjust the behaviour 
of [`variable_names`](@ref) accordingly:

```@example record-traces
Pigeons.variable_names(state::StateType, log_potential::LogPotentialType) = 
    [:log_density]
```
