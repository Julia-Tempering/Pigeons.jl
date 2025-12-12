#=
Methods common to all gradient-based samplers
=#

const GradientBasedSampler = Union{MALA, AutoMALA, AAPS}

### Dispatch on state for the behaviours for the different targets ###

step!(explorer::GradientBasedSampler, replica, shared) =
    step!(explorer, replica, shared, replica.state)


function step!(explorer::GradientBasedSampler, replica, shared, state::AbstractVector)
    log_potential = find_log_potential(replica, shared.tempering, shared)
    _extract_commons_and_run!(explorer, replica, shared, log_potential, state)
end


function gradient_based_sampler_recorders!(recorders, explorer::GradientBasedSampler)
    push!(recorders, buffers)
    push!(recorders, Pigeons.ad_buffers)
    if hasproperty(explorer, :preconditioner) && explorer.preconditioner isa AdaptedDiagonalPreconditioner
        push!(recorders, _transformed_online_full) # for mass matrix adaptation
    end
end
