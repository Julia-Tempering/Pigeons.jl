struct HMC

end

#= 

Useful fcts:

DynamicPPL.setall!(vi::VarInfo, val)


=#



"""
$SIGNATURES
"""
@provides explorer create_explorer(target::TuringLogPotential, inputs) = HMC() 

adapt_explorer(explorer::HMC, _, _) = explorer 
explorer_recorder_builders(::HMC) = [] 

step!(explorer::HMC, replica, shared) = step!(explorer, replica.state, replica.rng, find_log_potential(replica, shared))

function step!(explorer, state, rng, log_potential)
    v = init_velocity()
end