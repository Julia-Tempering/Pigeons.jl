"""
$SIGNATURES

Compute graph based state for targets with state-dependent infos

$FIELDS
"""
@auto mutable struct CG_state
    """
    Current state.
    """
    state

    """
    State-dependent cached infos
    """
    cached_info

    """
    Current coordinate
    """
    coord

    """
    Last value at current coord
    """
    pre_coord_val

end

""" 
$SIGNATURES

Update function for [`CG_state`](@ref). 
Does nothing by default and requires user-defined method for target.
"""

# doesn't do anything by default
function state_update(state, target; coord = nothing, update_coord = false) end

#=
Example:

@auto struct GLM_target
    dim::Int
    rows_x
    vec_y
    prior_var
end



function (p::GLM_target)(θ)
    ....
end

function (p::GLM_target)(θ::CG_state)
    ....
end

function state_update(state, target::GLM_target; coord = nothing, update_coord = false)
    if update_coord
        state.coord = coord
    else
        for i in 1:n
            state.cached_info.dot_prods[i] = ...
        end
    end
end
=#

#= 
TODO: add target info into explorers 
or add target-specific update functions to explorer
=#