"""
An encoding of a probability distribution, where only the un-normalized probability density function is known. 

Terminology: we use 'log_potential' for the log of an un-normalized probability density function.

Convention: we assume that if `f` is a log_potential, then it supports `f(x)`
"""

# Example implementations of log_potential's

(d::Distribution)(x) = logpdf(d, x)

