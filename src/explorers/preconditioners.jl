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
Furthermore, we use a zero-one-inflated Uniform(0,1) distribution for the mixing
proportion in order to make the preconditioner robust to extreme mismatch of
scales (see the autoMALA paper for more details).

$FIELDS
"""
struct MixDiagonalPreconditioner{TR<:Real} <: Preconditioner
    """Proportion of zeros"""
    p0::TR
    """Proportion of ones"""
    p1::TR
    function MixDiagonalPreconditioner(p0::TR,p1::TR) where {TR<:Real}
        zero(TR) ≤ p0+p1 ≤ one(TR) || throw(ArgumentError("p0+p1 < 0 or p0+p1 > 1"))
        new{TR}(p0,p1)
    end
end
MixDiagonalPreconditioner() = MixDiagonalPreconditioner(1//3,1//3)

const AdaptedDiagonalPreconditioner = Union{DiagonalPreconditioner,MixDiagonalPreconditioner}
adapt_preconditioner(::Preconditioner, args...) = nothing
adapt_preconditioner(::AdaptedDiagonalPreconditioner, reduced_recorders) =
    sqrt.(get_transformed_statistic(reduced_recorders, :singleton_variable, Variance))

build_preconditioner!(dest, ::Preconditioner, args...) = fill!(dest, one(eltype(dest)))
function build_preconditioner!(dest, ::DiagonalPreconditioner, rng, std_devs::Vector)
    @assert length(dest) == length(std_devs)
    @inbounds for i in eachindex(dest)
        dest[i] = std_devs[i] == 0. ? 1. : inv(std_devs[i])
    end
end
function build_preconditioner!(dest::Vector{T}, prec::MixDiagonalPreconditioner, rng, std_devs::Vector{T}) where {T<:Real}
    @assert length(dest) == length(std_devs)
    u = rand(rng)
    if u ≤ prec.p0
        map!(s -> iszero(s) ? one(T) : inv(s), dest, std_devs)
    elseif u ≤ prec.p0+prec.p1
        fill!(dest, one(T))
    else
        mix  = rand(rng,T)
        rmix = one(T)-mix
        map!(s -> iszero(s) ? one(T) : mix + rmix/s, dest, std_devs)
    end
    dest
end
