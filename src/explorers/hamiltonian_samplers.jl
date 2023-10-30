#=
Methods common to all Hamiltonian-based samplers
=#

const HamiltonianSampler = Union{MALA, AutoMALA, AAPS}

### Dispatch on state for the behaviours for the different targets ###

step!(explorer::HamiltonianSampler, replica, shared) =
    step!(explorer, replica, shared, replica.state)


function step!(explorer::HamiltonianSampler, replica, shared, state::AbstractVector)
    log_potential = find_log_potential(replica, shared.tempering, shared)
    _extract_commons_and_run!(explorer, replica, shared, log_potential, state)
end


function add_precond_recorder_if_needed!(recorders, explorer::HamiltonianSampler)
    if explorer.preconditioner isa AdaptedDiagonalPreconditioner
        push!(recorders, _transformed_online) # for mass matrix adaptation
    end
end
