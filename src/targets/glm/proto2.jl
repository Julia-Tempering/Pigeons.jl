# #=

# TODO: formalize notion of sneakiness for PPL
#     - performance sneakiness 
#     - universality sneakiness 

# bring in plate, assumed to be deterministic, but can be infinite

# Low-level CCG DSL constructs: (merge into one sugarized monster?)

# - accessing slices and applying a fct on each item 
#     - fixed slice 
#     - random slice 
#     - n-ary version

# - group operations, in particular, sum (technically optional)


# Useful construct: evaluator

# - inputs: 
#     - list of variable names in the scope 
#     - ordering info for validation (optional)
#     - lambda 
    
# map(dep1::Node{X1}, dep2::Node{X2}, ...) do d1::X1, d2::X2
#     runcode
# end

# node1[node2] -> node 

# remember e.g. node1[node2[node3 + g(node4)] + 5]

# -> idea: one type for each node of the graphical model, T{X} ???
#     - will be useful for dispatch
#     - use to control flow

# ---

# - type for random qts
# - rule of thumb: s itself should not be passed, 
#     instead, extract what to pass as a separate 
#     node in the graphical model 


# =#

# # here would have liked comprehension syntax, 
# # but it has large performance cost, separate
# # see https://docs.julialang.org/en/v1/manual/performance-tips/#man-performance-captured
# # and https://github.com/JuliaLang/julia/issues/15276
# # workaround seems annoying https://github.com/c42f/FastClosures.jl
# dot_prod(i, s) = sum(deterministic_seq, lambda) 


# @concrete struct CachedComputeGraph
#     input_variables
#     caches 
#     buffers 
#     stages 
# end

# @concrete struct Stage
#     fct 
#     key::Symbol
#     orders 
#     virtual
# end

# function update(cached, entry::Int, new_value)
#     # prepare buffers
#     for stage in cached.stages 

#     end
#     # perform updates
# end