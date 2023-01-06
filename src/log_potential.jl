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

# Example:
(d::Distribution)(x) = logpdf(d, x) 