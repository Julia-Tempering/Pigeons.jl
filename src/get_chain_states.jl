# n: Chain number (between 1 and N+1)
#' final: Whether to extract the *final* states only or include all of the tuning rounds
function get_chain_states(obj, n; final = true)
    if final
        chain_states = Vector{typeof(obj.FinalStates[1][1])}(undef, size(obj.FinalStates)[1])
        for i in 1:length(chain_states)
            chain_states[i] = obj.FinalStates[i][n]
        end
    else
        chain_states = Vector{typeof(obj.FinalStates[1][1])}(undef, size(obj.States)[1])
        for i in 1:length(chain_states)
            chain_states[i] = obj.States[i][n]
        end
    end
    return chain_states
end