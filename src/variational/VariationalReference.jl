#=
Methods common to all variational references
=#

# Currently implemented variational references
const VariationalReference = Union{GaussianReference, TreeReference, MixedTreeReference, DenseGaussianReference}

# Elide the AD buffering system
# Reasoning: 
#   1. Variational refs usually have analytic gradients anyway
#   2. It can be challenging to distinguish between the proper reference and the 
#      variational reference in the buffering system, especially since the var ref
#      is not activated immediately
get_buffer(
    ::Augmentation{<:Dict{Symbol, BufferedAD}}, 
    ::Symbol,
    kind,
    log_potential::VariationalReference,
    replica::Replica) = LogDensityProblemsAD.ADgradient(kind, log_potential, replica)
