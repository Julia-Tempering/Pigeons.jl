# For developers

## How to create doc locally

When the doc is built from the command line 
the process sometimes mysteriously hangs  
(this is not an issue in the CI). 
As a workaround, follow the instructions below. 

Start the VSCode REPL, then

```
]activate .
[ctrl-c]
using Pigeons # do this before to make sure we are loading the dev version 
;
cd docs
[ctrl-c]
]activate .
[ctrl-c]
include("make.jl")
```
