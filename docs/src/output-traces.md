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
using DynamicPPL
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
[`sample_names`](@ref) to obtain description of the 
vector components:

```@example record-traces
sample_names(pt)
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
value of the first coordinate:

```@example record-traces
struct OnlyFirstExtractor end 

Pigeons.extract_sample(state, log_potential, extractor::OnlyFirstExtractor) = 
    Pigeons.extract_sample(state, log_potential)[1:1]


pt = pigeons(;  target, 
                n_rounds = 3,
                # custom method to extract samples:
                extractor = OnlyFirstExtractor(),
                # make sure to record the trace:
                record = [traces; round_trip; record_default()])

sample_array(pt)
```

Optionally, it is a good idea to also adjust the behaviour 
of [`sample_names`](@ref) accordingly. For example, `variables_names` gets called 
when creating MCMCChains object so that e.g. plots are labelled correctly.

```@example record-traces
Pigeons.sample_names(state, log_potential, extractor::OnlyFirstExtractor) = 
    Pigeons.sample_names(state, log_potential)[1:1]
```

To keep only the value of the log potential, you can use the following built-in [`LogPotentialExtractor`](@ref):

```@example record-traces
pt = pigeons(;  target, 
                n_rounds = 3,
                # custom method to extract samples:
                extractor = Pigeons.LogPotentialExtractor(),
                # make sure to record the trace:
                record = [traces; round_trip; record_default()])

sample_array(pt)
```
