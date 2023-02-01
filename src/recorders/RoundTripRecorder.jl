"""
See [`round_trip()`](@ref).
"""
@kwdef mutable struct RoundTripRecorder 
    n_tempered_restarts::Int = 0
    n_round_trips::Int = 0
    #=
    Internal; encoding is:

        0: did not touch reference yet
            only transition is to 1, when ref is touched
        1: touched ref, and did not touched target since last reference  visit
            only transition is to 2, when target is touched (that transition increases n_tempered_restarts)
        2: touched target, and did not touched ref since last target visit 
            only transition is to 1, when ref is touched (that transition increases n_round_trips)
    =#
    state::Int = 0
end

"""$SIGNATURES"""
n_tempered_restarts(recorder::RoundTripRecorder) = recorder.n_tempered_restarts 
"""$SIGNATURES"""
n_round_trips(recorder::RoundTripRecorder) = recorder.n_round_trips 

"""$SIGNATURES"""
n_tempered_restarts(pt::PT) = n_tempered_restarts(pt.reduced_recorders.round_trip)
"""$SIGNATURES"""
n_round_trips(pt::PT) = n_round_trips(pt.reduced_recorders.round_trip)

function Base.empty!(recorder::RoundTripRecorder)
    recorder.n_tempered_restarts = 0
    recorder.n_round_trips = 0
    recorder.state = 0
end

function Base.merge(recorder1::RoundTripRecorder, recorder2::RoundTripRecorder)
    result = RoundTripRecorder()
    result.n_tempered_restarts = recorder1.n_tempered_restarts + recorder2.n_tempered_restarts
    result.n_round_trips = recorder1.n_round_trips + recorder2.n_round_trips
    return result
end

function record!(recorder::RoundTripRecorder, indicators)
    is_ref, is_target = indicators
    if recorder.state == 0 && is_ref 
        recorder.state = 1
    elseif recorder.state == 1 && is_target 
        recorder.state = 2 
        recorder.n_tempered_restarts += 1
    elseif recorder.state == 2 && is_ref 
        recorder.state = 1
        recorder.n_round_trips += 1
    end
end
