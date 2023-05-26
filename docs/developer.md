# For developers

## How to run tests locally 

From the root of the Pigeons repo:

```
julia 
]activate .
test
```

## How to create doc locally

To build the docs locally: `cd` to the `docs` directory, then:

```
julia
]activate .
[ctrl-c]
include("make.jl")
```
