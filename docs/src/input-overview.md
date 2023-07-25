```@meta
CurrentModule = Pigeons
```

# Overview: inputting an integral/expectation problem into pigeons

Pigeons takes as input an expectation or integration problem.
Pigeons supports a wide range of methods for specifying the input problem, 
described in the pages below. 

- [Turing.jl model](input-turing.html): a succinct specification of a joint distribution from which a posterior (target) and prior (reference) are extracted. 
- [Black-box Julia function](input-julia.html): less automated, but more general and fully configurable. 
- [Stan model](input-stan.html): a convenient adaptor for the most popular Bayesian modelling language. 
- [MCMC code implemented in another language](input-nonjulian.html): bridging your MCMC code to pigeons to make it distributed and parallel. 
- [Customize the MCMC explorers used by PT](input-explorers.html).

We exemplify these different input methods on a recurrent example: 
an unidentifiable toy model, 
see [the page describing the recurrent example in more details](unidentifiable-example.html). 