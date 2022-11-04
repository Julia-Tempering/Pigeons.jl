export randomwalkmetropolis

function randomwalkmetropolis(potential,state,β, η, Σ, nexpl)
    dimension = length(state)
    if β == 0 
        return rand(MvNormal(dimension, 1.0))
    else
        newstate = state + rand(MvNormal(dimension, Σ ))
        for n in 1:nexpl
            logratio = -potential(newstate, η) + potential(state, η)
            if log(rand()) < logratio
                state = newstate
            end
        end
    end
    return state
end

function randomwalkmetropolis(potential; Σ = 0.3, nexpl = 1)
    (state, β  ,η)->randomwalkmetropolis(potential, state, β ,η, Σ, nexpl)
end
