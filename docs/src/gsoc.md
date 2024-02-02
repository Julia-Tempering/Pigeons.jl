```@meta
CurrentModule = Pigeons
```
# [Pigeons Projects - Google Summer of Code](@id gsoc)

## Python and R Interface for Pigeons

Pigeons allows users to scale their Bayesian computation on up to thousands of 
machines. At the moment, the only available API is through the Julia programming 
language. To reach a wider audience, we would like to extend this to Python and R.
Work on this project would include: 

- Development of a new Pigeons interface in Python and/or R.

- Testing of the new interface to ensure identical output to Julia.  

- Engaging with researchers interested in using a Python/R interface and implementing additional suggested features. 

**Recommended Skills:** Familiarity with Python and/or R. A basic knowledge of 
statistical concepts and a desire to learn the basics of Julia and Bayesian inference.

**Expected Results:** An interface for Pigeons in either Python or R (or both). 

**Mentors:** [Alexandre Bouchard-Côté](https://github.com/alexandrebouchard), 
[Trevor Campbell](https://github.com/trevorcampbell/), and 
[Nikola Surjanovic](https://github.com/nikola-sur).

**Expected Project Size:** 175 hours or 350 hours. 

**Difficulty:** Medium.

<br>

## Automated Parameter Tuning

The core algorithm behind Pigeons, parallel tempering, has recently had [major developments](https://arxiv.org/abs/1905.02939). 
Some questions remain regarding the selection of tuning parameters in parallel tempering. 
While these have been partially theoretically resolved, it remains to automate 
the selection procedure in software such as Pigeons.
Work on this project would include:

- Development of an automated parameter selection procedure (e.g., the number of chains in parallel tempering). 

- Simulations to compare theoretical results and empirical performance.

- Further work on the parallelization of Pigeons (e.g., automated selection of number of machines and instances of parallel tempering).

**Recommended Skills:** Familiarity with Julia and distributed/parallel computing. 
A basic knowledge of statistical concepts. A desire to learn about the parallel tempering algorithm.

**Expected Results:** An automated tuning parameter selection procedure and a simplified user interface. 

**Mentors:** [Alexandre Bouchard-Côté](https://github.com/alexandrebouchard), 
[Trevor Campbell](https://github.com/trevorcampbell/), and 
[Nikola Surjanovic](https://github.com/nikola-sur).

**Expected Project Size:** 175 hours or 350 hours. 

**Difficulty:** Medium to Hard, depending on the chosen tasks.

<br>

## Automated Families for Variational Inference and MCMC 

The core algorithm behind Pigeons, parallel tempering, has recently had [major developments](https://arxiv.org/abs/1905.02939). 
In particular, [recent work](https://arxiv.org/abs/2206.00080) combines variational inference methods with 
parallel tempering to improve the performance of both. 
At the moment, Pigeons only implements basic variational families (e.g., mean-field Gaussians). 
Work on this project would include:

- Incorporating new and existing variational families within Pigeons. 

- Automated selection of variational families depending on the given computational problem. 

- Experimental comparison of the performance of various variational families on 
given computational tasks.

**Recommended Skills:** Familiarity with Julia. 
A basic knowledge of Bayesian statistical concepts. A desire to learn about parallel tempering and variational inference. 

**Expected Results:** An implementation of a rich collection of variational families within Pigeons, 
and an automated variational family selection procedure. 

**Mentors:** [Alexandre Bouchard-Côté](https://github.com/alexandrebouchard), 
[Trevor Campbell](https://github.com/trevorcampbell/), and 
[Nikola Surjanovic](https://github.com/nikola-sur).

**Expected Project Size:** 175 hours or 350 hours. 

**Difficulty:** Medium to Hard, depending on the chosen tasks.

<br>

## Library of Difficult Sampling Problems 

The fields of Bayesian statistical inference and statistical physics abound with 
difficult sampling problems. In the field of machine learning, it is common to compare 
methods across several standard data sets. 
In contrast, such collections of standard data sets and models do not exist or 
are limited in scope in the field of statistics.
(For example, the current, most commonly used library of difficult sampling problems, 
[posteriordb](https://github.com/stan-dev/posteriordb), does not emphasize 
difficult distributions such as non-log-concave targets.) Work on this project would include:

- Searching for difficult sampling problems in the literature and implementing some examples in Julia.

- Numerical experiments to compare the performance of Pigeons with other state-of-the-art sampling algorithms.

**Recommended Skills:** Familiarity with Julia, Markdown, and some basics of website development. 
A basic knowledge of statistical concepts. A desire to learn about the parallel tempering algorithm.

**Expected Results:** A website hosting a collection of difficult sampling problems with a user submission portal. 

**Mentors:** [Alexandre Bouchard-Côté](https://github.com/alexandrebouchard), 
[Trevor Campbell](https://github.com/trevorcampbell/), and 
[Nikola Surjanovic](https://github.com/nikola-sur).

**Expected Project Size:** 175 hours or 350 hours. 

**Difficulty:** Easy to Medium, depending on the chosen tasks.

