# Tests

## Running the tests locally

To activate the test environment, from the root of the Pigeons repo, type:

```
julia 
include("test/activate_test_env.jl")
```

Then to run all tests, use

```
include("test/runtests.jl")
```

which will automatically include() all files with 
the pattern "test/test_*.jl", 

or, to run one specific test, use 

```
include("test/test_allocs.jl")
```


