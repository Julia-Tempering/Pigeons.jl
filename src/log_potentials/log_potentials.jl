"""
An encoding of a discrete set of probability distributions, where only the un-normalized 
probability density functions are known. 
Each distribution is allowed to have a different normalization constant. 

For example, we provide this behaviour for any `Vector` containing [`log_potential`](@ref)'s. 
"""
@informal log_potentials begin
    """
    $(SIGNATURES)
    The argument `numerator` selects one distribution ``\\pi_i`` from the collection [`log_potentials`](@ref), 
    and similarly `denominator` selects ``\\pi_j``.
    Let ``x`` denote the input `state`.
    The ratio:

    ```math
    f(x) = \\frac{\\text{d}\\pi_i}{\\text{d}\\pi_j}(x)
    ```

    may only be known up to a normalization constant which can depend on ``i`` and ``j`` but 
    not ``x``, ``g(x) = C_{i,j} f(x)``.

    This function should return ``\\log g`` evaluated at `state`.
    """
    log_unnormalized_ratio(log_potentials, numerator::Int, denominator::Int, state) = @abstract 
    
    """
    $SIGNATURES 

    The number of chains in the [`log_potentials`](@ref).
    """
    n_chains(log_potentials) = length(log_potentials)
end


"""
$(SIGNATURES)
Assumes the input `log_potentials` is a vector where each element is a [`log_potential`](@ref).

This default implementation is sufficient in most cases, but in less standard scenarios,
e.g. where the state space is infinite dimensional, this can be overridden. 
"""
function log_unnormalized_ratio(log_potentials::AbstractVector, numerator::Int, denominator::Int, state)
    lp_num = log_potentials[numerator](state)
    lp_den = log_potentials[denominator](state)
    ans = lp_num-lp_den
    if isnan(ans)
        error("Got NaN log-unnormalized ratio; Dumping information:\n\tlp_num=$lp_num\n\tlp_den=$lp_den\n\tState=$state")
    end
    return ans
end
