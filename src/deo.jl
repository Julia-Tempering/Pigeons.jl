"""
    deo(potential, initial_state, InitialIndex, InitialLift, Schedule, ϕ, 
        nscan, N, resolution, optimreference_round, modref_means, modref_stds, modref_covs, 
        full_covariance, prior_sampler, n_explore)

Deterministic even-odd parallel tempering (DEO/NRPT).

# Arguments
- `potential`: Function as in NRPT, but with only two arguments: x and η
- `initial_state`: Starting state, as in NRPT. Input is of size: N+1 [ dim_x ]
- `InitialIndex`: Starting indices
- `InitialLift`: Starting lift
- `Schedule`: Annealing schedule
- `ϕ`: As in NRPT
- `nscan`: Number of scans to use
- `N`: As in NRPT
- `resolution`: As in NRPT
- `optimreference_round`: As in NRPT
- `modref_means`
- `modref_stds`
- `prior_sample`
"""
function deo(potential, initial_state, InitialIndex, InitialLift, Schedule, ϕ, 
    nscan::Int, N::Int, resolution::Int, optimreference_round, modref_means, modref_stds, modref_covs, 
    full_covariance::Bool, prior_sampler, n_explore::Int)  

    # Initialize
    Rejection = zeros(N)
    etas = computeetas(ϕ, Schedule)
    states = Vector{typeof(initial_state)}(undef, nscan + 1) # nscan+1 [ N+1 [ dim_x ] ]  
    states[1] = initial_state

    energies = Vector{typeof(potential.(initial_state,  eachrow(etas)))}(undef, nscan + 1)
    energies[1] = potential.(initial_state, eachrow(etas))

    indices = Vector{typeof(InitialIndex)}(undef, nscan + 1)
    indices[1] = InitialIndex

    lifts = Vector{typeof(InitialLift)}(undef, nscan + 1)
    lifts[1] = InitialLift

    Kernels = Vector{SS}(undef, size(etas)[1])
    Kernels = setKernels(potential, etas)

    ChainAcceptance = zeros(N+1)


    # Start scanning
    for n in 1:nscan
        # Perform scan
        New = DEOscan(potential, states[n], indices[n], lifts[n], etas, n, N, Kernels, 
        Schedule, optimreference_round, modref_means, modref_stds, modref_covs, 
        full_covariance, prior_sampler, n_explore)
        
        # Update 'states', 'energies', etc.
        states[n+1] = New.State
        energies[n+1] = New.Energy
        indices[n+1] = New.Index
        lifts[n+1] = New.Lift
        Rejection += New.Rejection # Rejection *probability* (stable) and not a rejection *count*
        ChainAcceptance += New.ChainAcceptance
    end


    # Prepare output
    Rejection = Rejection/nscan
    localbarrier, cumulativebarrier, GlobalBarrier = communicationbarrier(Rejection, Schedule)
    LocalBarrier = localbarrier.(range(0, 1, length = resolution))
    GlobalBarrier = GlobalBarrier
    norm_constant = lognormalizingconstant(reduce(hcat, energies)', Schedule)
    Schedule = updateschedule(cumulativebarrier, N) 
    etas = computeetas(ϕ, Schedule)
    RoundTrip = roundtrip(reduce(hcat, indices)')
    RoundTripRate = RoundTrip/nscan
    ChainAcceptanceRate = ChainAcceptance/nscan

    return (
        states              = states[2:end], # First state is from the previous round
        energies            = energies[2:end], 
        indices             = indices[2:end], 
        lifts               = lifts[2:end],
        Rejection           = Rejection,
        LocalBarrier        = LocalBarrier,
        GlobalBarrier       = GlobalBarrier,
        norm_constant = norm_constant,
        ScheduleUpdate      = Schedule,
        RoundTrip           = RoundTrip,
        RoundTripRate       = RoundTripRate,
        ChainAcceptanceRate = ChainAcceptanceRate,
        etas                = etas
)
end


"""
    DEOscan(potential, State, Index, Lift, etas, n, N, Kernels, Schedule, 
        optimreference_round, modref_means, modref_stds, modref_covs, full_covariance, 
        prior_sampler, n_explore) 

Perform one DEO scan (local exploration + communication). Arguments are 
similar to those for `deo()`. Note that `State` is the state from the **one** previous 
scan, which is of size N+1[dim_x].
"""
function DEOscan(potential, State, Index, Lift, etas, n, N, Kernels, Schedule, 
    optimreference_round, modref_means, modref_stds, modref_covs, full_covariance, 
    prior_sampler, n_explore) 
    
    # Local exploration phase    
    newState_full = LocalExploration(State, Kernels, optimreference_round, modref_means, 
    modref_stds, modref_covs, full_covariance, prior_sampler, n_explore)
    newState = newState_full.out
    ChainAcceptance = newState_full.ChainAcceptance

    newEnergy = potential.(newState, eachrow(etas)) # See acceptance.jl for more information
    newEnergy1 = potential.(newState[2:end], eachrow(etas[1:end-1, :])) 
    newEnergy2 = potential.(newState[1:end-1], eachrow(etas[2:end, :])) 
    newIndex = copy(Index)
    newLift = copy(Lift)

    # Communication phase
    # Compute acceptance probability
    Acceptance = acceptanceprobability(newEnergy, newEnergy1, newEnergy2)

    # Update rejection
    Rejection = 1 .- Acceptance # Vectorized
    # Odd/Even swaps
    isodd(n) ? (P = 1 :2:N) : (P = 2:2:N)
    for i ∈ P
        # Swap states i and i+1
        i_1, i_2 = findfirst(Index .== i), findfirst(Index .== i+1)
        if rand(Bernoulli(Acceptance[i]))
            # Perform swap
            newState[i], newState[i+1] = newState[i+1], newState[i]
            newEnergy[i], newEnergy[i+1] = newEnergy[i+1], newEnergy[i]
            newIndex[i_1], newIndex[i_2] = i+1, i
        end
    end

    for j ∈ 1:N+1
        if newIndex[j] != Index[j]+Lift[j]
            newLift[j] = -Lift[j] # Change direction
        end
    end
    return (
        State           = newState, 
        Energy          = newEnergy, 
        Index           = newIndex, 
        Lift            = newLift, 
        Rejection       = Rejection,
        ChainAcceptance = ChainAcceptance)
end