"""
    deo(potential, initial_state, initial_index, initial_lift, schedule, ϕ, 
        nscan, N, resolution, optimreference_round, modref_means, modref_stds, modref_covs, 
        full_covariance, prior_sampler, n_explore)

Deterministic even-odd parallel tempering (DEO/NRPT).

# Arguments
- `potential`: Function as in NRPT, but with only two arguments: x and η
- `initial_state`: Starting state, as in NRPT. Input is of size: N+1 [ dim_x ]
- `initial_index`: Starting indices
- `initial_lift`: Starting lift
- `schedule`: Annealing schedule
- `ϕ`: As in NRPT
- `nscan`: Number of scans to use
- `N`: As in NRPT
- `resolution`: As in NRPT
- `optimreference_round`: As in NRPT
- `modref_means`
- `modref_stds`
- `prior_sample`
"""
function deo(potential, initial_state, initial_index, initial_lift, schedule, ϕ, 
    nscan::Int, N::Int, resolution::Int, optimreference_round, modref_means, modref_stds, modref_covs, 
    full_covariance::Bool, prior_sampler, n_explore::Int)  

    # Initialize
    Rejection = zeros(N)
    etas = computeetas(ϕ, schedule)
    states = Vector{typeof(initial_state)}(undef, nscan + 1) # nscan+1 [ N+1 [ dim_x ] ]  
    states[1] = initial_state

    energies = Vector{typeof(potential.(initial_state,  eachrow(etas)))}(undef, nscan + 1)
    energies[1] = potential.(initial_state, eachrow(etas))

    indices = Vector{typeof(initial_index)}(undef, nscan + 1)
    indices[1] = initial_index

    lifts = Vector{typeof(initial_lift)}(undef, nscan + 1)
    lifts[1] = initial_lift

    kernels = Vector{SS}(undef, size(etas)[1])
    kernels = setkernels(potential, etas)

    chainacceptance = zeros(N+1)


    # Start scanning
    for n in 1:nscan
        # Perform scan
        New = DEOscan(potential, states[n], indices[n], lifts[n], etas, n, N, kernels, 
        schedule, optimreference_round, modref_means, modref_stds, modref_covs, 
        full_covariance, prior_sampler, n_explore)
        
        # Update 'states', 'energies', etc.
        states[n+1] = New.state
        energies[n+1] = New.Energy
        indices[n+1] = New.index
        lifts[n+1] = New.lift
        Rejection += New.Rejection # Rejection *probability* (stable) and not a rejection *count*
        chainacceptance += New.chainacceptance
    end


    # Prepare output
    Rejection = Rejection/nscan
    localbarrier, cumulativebarrier, globalbarrier = communicationbarrier(Rejection, schedule)
    localbarrier = localbarrier.(range(0, 1, length = resolution))
    globalbarrier = globalbarrier
    norm_constant = lognormalizingconstant(reduce(hcat, energies)', schedule)
    schedule = updateschedule(cumulativebarrier, N) 
    etas = computeetas(ϕ, schedule)
    RoundTrip = roundtrip(reduce(hcat, indices)')
    RoundTripRate = RoundTrip/nscan
    chain_acceptance_rate = chainacceptance/nscan

    return (
        states              = states[2:end], # First state is from the previous round
        energies            = energies[2:end], 
        indices             = indices[2:end], 
        lifts               = lifts[2:end],
        Rejection           = Rejection,
        localbarrier        = localbarrier,
        globalbarrier       = globalbarrier,
        norm_constant = norm_constant,
        scheduleUpdate      = schedule,
        RoundTrip           = RoundTrip,
        RoundTripRate       = RoundTripRate,
        chain_acceptance_rate = chain_acceptance_rate,
        etas                = etas
)
end


"""
    DEOscan(potential, state, index, lift, etas, n, N, kernels, schedule, 
        optimreference_round, modref_means, modref_stds, modref_covs, full_covariance, 
        prior_sampler, n_explore) 

Perform one DEO scan (local exploration + communication). Arguments are 
similar to those for `deo()`. Note that `state` is the state from the **one** previous 
scan, which is of size N+1[dim_x].
"""
function DEOscan(potential, state, index, lift, etas, n, N, kernels, schedule, 
    optimreference_round, modref_means, modref_stds, modref_covs, full_covariance, 
    prior_sampler, n_explore) 
    
    # Local exploration phase    
    newstate_full = LocalExploration(state, kernels, optimreference_round, modref_means, 
    modref_stds, modref_covs, full_covariance, prior_sampler, n_explore)
    newstate = newstate_full.out
    chainacceptance = newstate_full.chainacceptance

    newEnergy = potential.(newstate, eachrow(etas)) # See acceptance.jl for more information
    newEnergy1 = potential.(newstate[2:end], eachrow(etas[1:end-1, :])) 
    newEnergy2 = potential.(newstate[1:end-1], eachrow(etas[2:end, :])) 
    newindex = copy(index)
    newlift = copy(lift)

    # Communication phase
    # Compute acceptance probability
    Acceptance = acceptanceprobability(newEnergy, newEnergy1, newEnergy2)

    # Update rejection
    Rejection = 1 .- Acceptance # Vectorized
    # Odd/Even swaps
    isodd(n) ? (P = 1 :2:N) : (P = 2:2:N)
    for i ∈ P
        # Swap states i and i+1
        i_1, i_2 = findfirst(index .== i), findfirst(index .== i+1)
        if rand(Bernoulli(Acceptance[i]))
            # Perform swap
            newstate[i], newstate[i+1] = newstate[i+1], newstate[i]
            newEnergy[i], newEnergy[i+1] = newEnergy[i+1], newEnergy[i]
            newindex[i_1], newindex[i_2] = i+1, i
        end
    end

    for j ∈ 1:N+1
        if newindex[j] != index[j]+lift[j]
            newlift[j] = -lift[j] # Change direction
        end
    end
    return (
        state           = newstate, 
        Energy          = newEnergy, 
        index           = newindex, 
        lift            = newlift, 
        Rejection       = Rejection,
        chainacceptance = chainacceptance)
end