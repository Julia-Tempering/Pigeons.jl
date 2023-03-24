# Pigeons.jl

<!---
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://github.com/Julia-Tempering/Pigeons.jl/stable/)
--->
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://julia-tempering.github.io/Pigeons.jl/dev/)
[![Build Status](https://github.com/Julia-Tempering/Pigeons.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/Julia-Tempering/Pigeons.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/Julia-Tempering/Pigeons.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/Julia-Tempering/Pigeons.jl)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

Pigeons.jl enables users to leverage distributed computation to obtain samples from complex distributions, such as those arising in Bayesian inference and statistical mechanics. It can easily be used in a multi-threaded context and/or distributed over thousands of MPI-communicating machines.

:warning: **Warning** <br>
This package is currently under development. The user interface may change substantially prior to the first stable release.
Please [view our documentation](https://julia-tempering.github.io/Pigeons.jl/dev/) for the most up-to-date description. Additionally, the implementation of parallel tempering
with a variational reference will be available in the very near future.


## Timeline

The following features should be implemented according to the timeline given below:
- Sampling on discrete state spaces: January 2023 :heavy_check_mark:
- Parallel tempering with a variational reference: April 2023
- "Parallel parallel" tempering (multiple copies of parallel tempering): April 2023

## Funding and acknowledgments 

The development and testing of Pigeons.jl is supported by the Natural Sciences and Engineering Research Council of Canada Discovery Grant and Vanier programs, and by the University of British Columbia Advanced Research Computing. The authors would like to thank Roman Baranowski, Jacob Boschee and Alyza Rosario for their help with MPI.
