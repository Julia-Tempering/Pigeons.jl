# Pigeons.jl

<!---
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://github.com/Julia-Tempering/Pigeons.jl/stable/)
--->
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://julia-tempering.github.io/Pigeons.jl/dev/)
[![Build Status](https://github.com/Julia-Tempering/Pigeons.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/Julia-Tempering/Pigeons.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/Julia-Tempering/Pigeons.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/Julia-Tempering/Pigeons.jl)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

`Pigeons` is a Julia package to approximate challenging posterior distributions, and more broadly, Lebesgue integration problems. Pigeons can be used in a multi-threaded context, and/or distributed over hundreds or thousands of MPI-communicating machines.

[For more information, see the documentation.](https://pigeons.run/dev/)


## Funding and acknowledgments 

The development and testing of Pigeons.jl is supported by the Natural Sciences and Engineering Research Council of Canada Discovery Grant and Vanier programs, and by the University of British Columbia Advanced Research Computing. The authors would like to thank Roman Baranowski, Jacob Boschee and Alyza Rosario for their help with MPI.


## How to cite Pigeons 

Our team works hard to maintain and improve the Pigeons package. Please consider citing our work by referring to [our Pigeons paper](https://arxiv.org/abs/2308.09769).

**BibTeX code for citing Pigeons**

```
@article{surjanovic2023pigeons,
  title={Pigeons.jl: {D}istributed sampling from intractable distributions},
  author={Surjanovic, Nikola and Biron-Lattes, Miguel and Tiede, Paul and Syed, Saifuddin and Campbell, Trevor and Bouchard-C{\^o}t{\'e}, Alexandre},
  journal={arXiv:2308.09769},
  year={2023}
}
```

**APA**

Surjanovic, N., Biron-Lattes, M., Tiede, P., Syed, S., Campbell, T., & Bouchard-Côté, A. (2023). Pigeons.jl: Distributed sampling from intractable distributions. *arXiv:2308.09769.*
