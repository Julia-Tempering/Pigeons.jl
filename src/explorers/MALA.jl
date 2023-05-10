struct MALA 
    step_size::Float64
    n_passes::Int
end

explorer_recorder_builders(explorer::MALA) = explorer_recorder_builders(static_HMC())

function step!(explorer::MALA, replica, shared)
    hmc = static_HMC(-1.0, explorer.n_passes) 
    step!(hmc, replica, shared, explorer.step_size, 1)
end