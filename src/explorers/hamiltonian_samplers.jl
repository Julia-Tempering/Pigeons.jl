#=
Methods common to all Hamiltonian-based samplers
=#

const HamiltonianSampler = Union{MALA, AutoMALA, AAPS}

### Dispatch on state for the behaviours for the different targets ###

step!(explorer::HamiltonianSampler, replica, shared) = 
    step!(explorer, replica, shared, replica.state)

step!(explorer::HamiltonianSampler, replica, shared, state::StanState) = 
    step!(explorer, replica, shared, state.unconstrained_parameters)

function add_precond_recorder_if_needed!(recorders, explorer::HamiltonianSampler)
    if explorer.preconditioner isa AdaptedDiagonalPreconditioner
        push!(recorders, _transformed_online) # for mass matrix adaptation
    end
end
