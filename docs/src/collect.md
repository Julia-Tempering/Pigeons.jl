# Collecting the PT output

Parallel tempering produces a set of samples which can be 
used to perform many tasks:

1. estimating normalization constants (uses a univariate statistic 
    from each chain);
2. estimating expectations (uses potentially high-dimensional 
    statistics from a single chain, the target one).

Here we focus on the design of the machinery for achieving point 2 above in the distributed parallel tempering context. 

The main challenges are:

- (A) each machine holds a subset of the samples; this complicates the 
    computation of order-sensitive estimators such as batch-mean 
    asymptotic variance estimators for Monte Carlo standard error 
    estimation;
- (B) in some applications, it may not be possible to hold all the 
    samples in the memory of one machine. At the extreme, a
    machine may not be able to store more than one sample. 
    

## Possible approaches

First decision:

1. perform collection during sampling using online-statistics only
2. store samples to RAM and do processing after sampling
3. same as 2 but with hard-drive storage
4. support several of 1-3, potentially using different strategies for different statistic and/or targets

Constraints:

- technical challenges (A) and (B)
- default settings should be fast...
- ...but also ergonomic


## Plan for next step on this

- We now have a working version of collection for samples 
    that are not order-sensitive
- for order sensitive, do some benchmarking to compare the 
    different approaches 1-3. 





