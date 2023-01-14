# Pigeons.jl

<!---
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://github.com/Julia-Tempering/Pigeons.jl/stable/)
--->
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://github.com/Julia-Tempering/Pigeons.jl/dev/)
[![Build Status](https://github.com/Julia-Tempering/Pigeons.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/Julia-Tempering/Pigeons.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/Julia-Tempering/Pigeons.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/Julia-Tempering/Pigeons.jl)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

Distributed Non-Reversible Parallel Tempering

:warning: **Warning** <br>
This package is currently under development. The user interface may change substantially prior to the first stable release.
Please view our documentation for the most up-to-date description. Additionally, the implementation of parallel tempering
with a variational reference will be available in the very near future.

## Install

At the moment (TODO: publish Pigeons.jl to registry)

```
]
dev git@github.com:Julia-Tempering/Pigeons.jl.git
```

Since latter is private, you may have to add to your .profile file:

```
export SSH_KEY_PATH=/path/to/user/.ssh/id_rsa
export SSH_PUB_KEY_PATH=/path/to/user/.ssh/id_rsa.pub
```

## Instructions to run MPI code

From log-in node:

- Clone into a shared folder in a MPI cluster 
- Inside the cloned repo, call `./mpi-setup` 
- To launch a job, type `./mpi-run -h` to see an example and documentation. **Note:** you may need to run first with a single node to avoid Julia compilation crashing due to concurrent access to the .julia folder. 
- To monitor the job, type `./mpi-watch`
