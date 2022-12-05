"""
Convention: we assume that if `logf` is a log_potential, then it supports `logf(x)`
"""

# Example implementations of log_potential's

(d::Distribution)(x) = logpdf(d, x)
