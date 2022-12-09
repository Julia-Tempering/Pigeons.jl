```@meta
CurrentModule = Pigeons
```


## Introduction

We provide in this page an overview of Non-Reversible Parallel Tempering (PT), 
[Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).


Let $X_n$ denote a Markov chain on state space `S` with stationary distribution
$\pi$. 



We denote one point 

We refer the reader to [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464) for more 
background on PT algorithms. 




We start with a some terminology and then provide an overview of distributed/parallel PT, focussing on 
the parts that involve communication between machines and/or threads. 






- [Replica](@ref): a point in the state space. **add doc right here instead?**

```@docs
Pigeons.Replica
```



**show pic**

**replicas**
