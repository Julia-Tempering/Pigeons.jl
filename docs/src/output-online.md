```@meta
CurrentModule = Pigeons
```

# Online (constant memory) statistics 

When the dimensionality of a model is large and/or the 
number of MCMC samples is large, the samples may not 
fit in memory. 
The most flexible way to deal with this situation is 
to write sample to disk and process them one at the time, 
as described in [the off-memory processing documentation](output-off-memory.html). 
However, certain statistics can be computed using fixed 
dimensional sufficient statistics yielding more 
efficient algorithms. We describe this alternative here. 


## Built-in online statistics: mean and variance 

```example online
using Pigeons
using OnlineStats

# example target: Binomial likelihood with parameter p = p1 * p2
an_unidentifiable_model = Pigeons.toy_turing_unid_target()

pt = pigeons(
        target = an_unidentifiable_model, 
        record = [online]
    )

using Statistics 
mean(pt)
```