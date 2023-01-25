"""
Gaussian sampler for paths where some of the distributions on the 
annealing path are (multivariate) normal. Produces i.i.d. samples. 
"""
struct GaussianSampler end

"""
$SIGNATURES
"""
@provides explorer 