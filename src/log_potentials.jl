"""
An encoding of a discrete set of probability distributions, where only the un-normalized probability density functions are known. 
Each distribution is allowed to have a different normalization constant. 
"""

"""
More broadly, this evaluates the log of a Radon-Nikodym derivative up to a normalization constant.
That normalization constant can depend on both integer indices but not on the state.
"""
#log_unnormalized_ratio(log_potentials, numerator::Int, denominator::Int, state) = @abstract 


"""
When the log_potentials have a common dominating measure, return the different of the log potentials.
"""
log_unnormalized_ratio(log_potentials::AbstractVector, numerator::Int, denominator::Int, state) = 
    log_potentials[numerator](state) - log_potentials[denominator](state)


