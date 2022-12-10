```@meta
CurrentModule = Pigeons
```


## Introduction

We provide in this page an overview of Non-Reversible Parallel Tempering (PT), 
[Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464), 
linking it with some key parts of the code base. 

Let ``X_n`` denote a Markov chain on state space ``\mathscr{X}`` with stationary distribution
``\pi``. 
PT is a Markov chain defined on the augmented state space ``\mathscr{X}^N``, hence 
a state has the form ``\boldsymbol{X} = (X^{(1)}, X^{(2)}, \dots, X^{(N)})``. 
Each component of ``\boldsymbol{X}`` is stored in a struct called a
[`Replica`](@ref). 

The storage of the vector of replicas ``\boldsymbol{X}``, is done via the informal 
interface [`replicas`](@ref). In the context of PT running on one computer, 
[`replicas`](@ref) is implemented with a `Vector{Replica}`. In the context 
of running PT distributed across several communicating machines, [`replicas`](@ref) 
is implemented via [`EntangledReplicas`](@ref), which stores the parts of 
``\boldsymbol{X}`` that are local to that machine as well as data structures 
required to communicate with the other machines. 

PT is designed so that its invariant distribution is ``\boldsymbol{\pi} = \pi_1 \times \pi_2 \times \dots \pi_N``. 
The algorithm alternates between two phases, each ``\boldsymbol{\pi}``-invariant. 
In the local exploration phase, 
each XXX







- [Replica](@ref): a point in the state space. **add doc right here instead?**



**show pic**

**replicas**
