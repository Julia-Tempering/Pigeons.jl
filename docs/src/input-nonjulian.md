```@meta
CurrentModule = Pigeons
```

# [Targeting a non-Julian model](@id input-nonjulian)

Suppose you have some code implementing vanilla MCMC, written in an arbitrary "foreign" language such as C++, Python, R, Java, etc. You would like to turn this vanilla MCMC code into a Parallel Tempering algorithm able to harness large numbers of cores, including distributing this algorithm over MPI. However, you do not wish to learn anything about MPI/multi-threading/Parallel Tempering.

Surprisingly, it is very simple to bridge such code with Pigeons. The only requirement on the "foreign" language is that it supports reading the standard in and writing to the standard out, hence virtually any languages can be interfaced in this fashion. Based on this minimalist "standard stream bridge" with worker processes running foreign code (one such process per replica; not necessarily running on the same machine), Pigeons will coordinate the execution of an adaptive non-reversible parallel tempering algorithm.

This behaviour is implemented in [`StreamTarget`](@ref), see its documentation for details. 
In a nutshell, there will be one child process for each PT chain.
These processes will not necessarily be on 
the same machine: indeed distributed sampling is the key use case of this bridge. 
Pigeons will do some 
lightweight coordination with these child processes to orchestrate non-reversible
parallel tempering. 
Interprocess communication only involves pigeons telling each child process 
to perform exploration at a pigeons-provided annealing parameter. 

[`StreamTarget`](@ref) implements [`log_potential`](@ref) and [`explorer`](@ref) 
by invoking worker processes via standard stream communication.
The standard stream is less efficient than alternatives such as 
protobuff, but it has the advantage of being supported by nearly all 
programming languages in existence. 
Also in many practical cases, since the worker 
process is invoked only three times per chain per iteration, it is
unlikely to be the bottleneck (overhead is in the order of 0.1ms per interprocess call).  



## Usage example

To demonstrate this capability, we show 
here how it enables running Blang models in 
pigeons. 
[Blang](https://github.com/UBC-Stat-ML/blangSDK) is a Bayesian modelling language designed 
for sampling combinatorial spaces such as 
phylogenetic trees. 

We first setup Blang as follows (assuming Java 11 is accessible in the `PATH` variable):

```@example blang
using Pigeons

Pigeons.setup_blang("blangDemos") 
```

Next, we run a  
[Blang implementation](https://github.com/UBC-Stat-ML/blangDemos/blob/master/src/main/java/demos/UnidentifiableProduct.bl) of 
our usual [unidentifiable toy example](@ref unidentifiable-example):

```@example blang
using Pigeons

blang_unidentifiable_example(n_trials, n_successes) = 
    Pigeons.BlangTarget(
        `$(Pigeons.blang_executable("blangDemos", "demos.UnidentifiableProduct")) --model.nTrials $n_trials --model.nFails $n_successes`
    )
pt = pigeons(target = blang_unidentifiable_example(100, 50))
nothing # hide
```

As shown above, create a [`StreamTarget`](@ref) amounts to specifying which command will 
be used to create a child process. 