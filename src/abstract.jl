# Abstract Tempering Density that will be evaluated
abstract type AbstractTemperingDensity end
target(d::TemperingDensity) = d.target
reference(d::TemperingDensity) = d.reference
path(d::TemperingDensity) = d.path


abstract type AbstractPath end
struct LinearPath <: AbstractPath end

@abstractmethod computeeta(path::AbstractPath, β::Real)
computeeta(::LinearPath, β::Real) = (β, 1-β)


struct TemperingDensity{T,R,P <: AbstractPath} <: AbstractTemperingDensity
    target::V
    reference::R
    path::P
end

computeeta(d::AbstractTemperingDensity, β) = computeeta(path(d), β)


# Define some singleton types to specify the type of parallel scheme we will be using

abstract type CommunicationScheme end

"""
    MPICommScheme

Uses MPI to parallelize communication between difference replicas
"""
struct MPICommScheme <: CommunicationScheme end

"""
    SerialCommScheme

Does not parallelize the communication between different replicas.

# Warning

This is very slow! Use MPICommScheme for the fastest sampling.
"""
struct SerialCommScheme <: CommunicationScheme end
