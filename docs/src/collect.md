# Collecting the PT output

Parallel tempering produces a set of samples which can be 
used to peform many tasks:

1. estimating normalization constants (uses a univariate statistic 
    from each chain);
2. estimating expectations (uses potentially high-dimensional 
    statistics from a single chain, the target one).

Here we focus on the design of the machinery for achieving point 2 above in the distributed parallel tempering context. 

The main challenges are:

- each machine holds a subset of the samples; this complicates the 
    computation of order-sensitive estimators such as batch-mean 
    asymptotic variance estimators for Monte Carlo standard error 
    estimation;
- in some applications, it may not be possible to hold all the 
    samples in the memory of one machine. At the extreme, a
    machine may not be able to store more than one sample. 