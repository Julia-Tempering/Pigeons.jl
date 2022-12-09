"""
An log_potential encodes a probability distribution, where only the 
un-normalized probability density function is known. 

To make MyType conforms this informal interface, implement 

    (log_potential::MyType)(x)

which should return the log of the un-normalized density.
"""
# Example:
(d::Distribution)(x) = logpdf(d, x) 