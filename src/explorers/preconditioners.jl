""" 
$SIGNATURES

An abstract type for preconditioners. See [`IdentityPreconditioner`](@ref), 
[`DiagonalPreconditioner`](@ref), and [`MixDiagonalPreconditioner`](@ref).
"""
abstract type Preconditioner end

""" 
$SIGNATURES

Uses the identity as preconditioner. Equivalent to no preconditioning.
"""
struct IdentityPreconditioner <: Preconditioner end

""" 
$SIGNATURES

Constructs a diagonal preconditioner using the estimated precisions of the samples 
from the previous round.
"""
struct DiagonalPreconditioner <: Preconditioner end

""" 
$SIGNATURES

Similar to [`DiagonalPreconditioner`](@ref) but the actual preconditioner used
at each iteration is a random mixture of the identity and the adapted diagonal
matrix. This helps with targets featuring distantly separated modes, which induces
average standard deviations that are much higher than the ones within each mode. 
Suggested by [Max Hird](https://maxhhird.github.io/) (personal communication).
"""
struct MixDiagonalPreconditioner <: Preconditioner end

const AdaptedDiagonalPreconditioner = Union{DiagonalPreconditioner,MixDiagonalPreconditioner}
adapt_preconditioner(::Preconditioner, args...) = nothing
adapt_preconditioner(::AdaptedDiagonalPreconditioner, reduced_recorders) =
    sqrt.(get_transformed_statistic(reduced_recorders, :singleton_variable, Variance))

build_preconditioner!(dest, ::Preconditioner, args...) = fill!(dest, one(eltype(dest)))
function build_preconditioner!(dest, ::DiagonalPreconditioner, rng, std_devs::Vector)
    dest .= inv.(std_devs)
end
function build_preconditioner!(dest, ::MixDiagonalPreconditioner, rng, std_devs::Vector)
    mix   = rand(rng)
    dest .= mix .* one(mix) .+ (one(mix) - mix) ./ std_devs
end
