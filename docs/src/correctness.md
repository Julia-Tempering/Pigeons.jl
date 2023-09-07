```@meta
CurrentModule = Pigeons
```

## Correctness checks for distributed/parallel algorithms

It is notoriously difficult to implement correct parallel/distributed algorithms. 
One strategy we use to address this is to guarantee that the code will output 
precisely the same output no matter how many threads/machines are used. 
We describe how this is done under the hood in the page [Distributed PT](@ref distributed). 

In practice, how is this useful? Let us say you developed a new target and you would like
to make sure that it works correctly in a multi-threaded environment. To do so, add a flag to indicate to "check" one of the PT rounds as follows, and 
enable checkpointing

```@example example
using Pigeons
pigeons(target = toy_mvn_target(100), checked_round = 3, checkpoint = true)
nothing # hide
```

The above line does the following: the PT algorithm will pause at the end of round 3, spawn 
a separate process with only one thread in it, run 3 rounds of PT with the same 
[`Inputs`](@ref) object in it, and verify that the checkpoints of the single-threaded run 
is identical to  
the one that ran in the main process. If not, an error will be raised with some 
information on where the discrepancy comes from. 
Try to pick the checked round to be small enough that it does not dominate the running time 
(since it runs in single-threaded, single-process mode), but big enough to achieve 
the same code coverage as the full algorithm. Setting it to zero (or omitting the argument), 
disables this functionality.

Did the code above actually use many threads? This depends on the value of
`Threads.nthreads()`. Julia currently does not allow you to change this value at 
runtime, so for convenience we provide the following way to run the job in a 
child process with a set number of Julia threads:

```@example example
pt_result = pigeons(target = toy_mvn_target(100), multithreaded = true, checked_round = 3, checkpoint = true, on = ChildProcess(n_threads = 4))
```

Notice that we also add the flag `multithreaded = true`, to instruct Pigeons to use 
the multiple threads available to parallelize exploration across chains (in other use cases, 
parallelization might get used internally e.g. to parallelize likelihood evaluation).

Here the check passed successfully as expected. But what 
if you had a third-party target distribution that is not multi-threaded friendly? 
For example some code sometimes write in global variables or 
other non-thread safe constructs. In such situation, you can  still  use your thread-naive 
target over MPI *processes*. 
For example, if the thread-unsafety comes from the use of global variables, then each 
process will have its own copy of the global variables. 

