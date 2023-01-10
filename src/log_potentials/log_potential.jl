"""
A `log_potential` encodes a probability distribution, where only the 
un-normalized probability density function is known. 

To make MyType conform to this informal interface, implement 

    (log_potential::MyType)(x)

which should return the log of the un-normalized density.

For example, we provide this behaviour for any distribution 
in Distributions.jl. 
"""
@informal log_potential begin
    
end

""" 
$SIGNATURES 

Given a target (a [`log_potential`](@ref)) and the inputs, 
create a suitable reference distribution. The return type 
should conform [`log_potential`](@ref). 
""" 
@provides log_potential create_reference(target, inputs::Inputs) = @abstract 

# Toy example:
(d::Distribution)(x) = logpdf(d, x) 