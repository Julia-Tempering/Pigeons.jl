#' Deterministic even-odd parallel tempering (DEO/NRPT)
#'
#' Performs NRPT with DEO
#'
#' @param potential Function as in NRPT, but with only two arguments: x and η
#' @param InitialState Starting state, as in NRPT. Input is of size: N+1 [ dim_x ]
#' @param InitialIndex Starting indices
#' @param InitialLift Starting lift
#' @param Schedule Annealing schedule
#' @param Phi As in NRPT
#' @param nscan Number of scans to use
#' @param N As in NRPT
#' @param verbose As in NRPT
#' @param resolution As in NRPT
#' @param optimreference_round As in NRPT
#' @param modref_means
#' @param modref_stds
#' @param prior_sampler
#' @param chain_stds For tuning HMC exploration. N+1 [ dim_x]. Stores the estimated standard deviations from each chain based on the previous tuning round.
function deo(potential, InitialState, InitialIndex, InitialLift, Schedule, Phi, nscan, N, verbose, resolution, optimreference_round, modref_means, modref_stds, modref_covs, full_covariance, prior_sampler, chain_stds, HMC_std_multiplier, L, explore_target, n_explore)  

    # Initialize
    Rejection = zeros(N)
    Etas = computeEtas(Phi, Schedule)
    States = Vector{typeof(InitialState)}(undef, nscan + 1) # nscan+1 [ N+1 [ dim_x ] ]  
    States[1] = InitialState

    Energies = Vector{typeof(potential.(InitialState,  eachrow(Etas)))}(undef, nscan + 1)
    Energies[1] = potential.(InitialState, eachrow(Etas))

    Indices = Vector{typeof(InitialIndex)}(undef, nscan + 1)
    Indices[1] = InitialIndex

    Lifts = Vector{typeof(InitialLift)}(undef, nscan + 1)
    Lifts[1] = InitialLift

    Kernels = Vector{SS}(undef, size(Etas)[1])
    Kernels = setKernels(potential, Etas, L)

    ChainAcceptance = zeros(N+1)


    # Start scanning
    for n in 1:nscan
        # Perform scan
        New = DEOscan(potential, States[n], Indices[n], Lifts[n], Etas, n, N, Kernels, Schedule, optimreference_round, modref_means, modref_stds, modref_covs, full_covariance, prior_sampler, chain_stds, HMC_std_multiplier, explore_target, n_explore)
        
        # Update 'States', 'Energies', etc.
        States[n+1] = New.State
        Energies[n+1] = New.Energy
        Indices[n+1] = New.Index
        Lifts[n+1] = New.Lift
        Rejection += New.Rejection # Rejection *probability* and not a rejection *count* --> more stable computation!
        ChainAcceptance += New.ChainAcceptance
    end


    # Prepare output
    Rejection = Rejection/nscan
    localbarrier, cumulativebarrier, GlobalBarrier = communicationbarrier(Rejection, Schedule)
    LocalBarrier = localbarrier.(range(0, 1, length = resolution))
    GlobalBarrier = GlobalBarrier
    NormalizingConstant = lognormalizingconstant(reduce(hcat, Energies)', Schedule)
    Schedule = updateschedule(cumulativebarrier, N) 
    Etas = computeEtas(Phi, Schedule)
    RoundTrip = roundtrip(reduce(hcat, Indices)')
    RoundTripRate = RoundTrip/nscan
    ChainAcceptanceRate = ChainAcceptance/nscan

    # Print additional information
    if verbose
        println("Average rejection rate = $(mean(Rejection))")
        println("Min rejection rate = $(minimum(Rejection))")
        println("Max rejection rate = $(maximum(Rejection))")
        println("Global barrier ≈ $GlobalBarrier")
        println("Log-normalizing constant = $(NormalizingConstant)")
        println("Total round trips = $RoundTrip")
        println("Round trip rate = $RoundTripRate")
    end

    return (
        States              = States[2:end], # Intentional! (First element is from the previous tuning round)
        Energies            = Energies[2:end], 
        Indices             = Indices[2:end], 
        Lifts               = Lifts[2:end],
        Rejection           = Rejection,
        LocalBarrier        = LocalBarrier,
        GlobalBarrier       = GlobalBarrier,
        NormalizingConstant = NormalizingConstant,
        ScheduleUpdate      = Schedule,
        RoundTrip           = RoundTrip,
        RoundTripRate       = RoundTripRate,
        ChainAcceptanceRate = ChainAcceptanceRate,
        Etas                = Etas
)
end



# State: The state from the one previous scan. Of size: N+1 [dim_x]
function DEOscan(potential, State, Index, Lift, Etas, n, N, Kernels, Schedule, optimreference_round, modref_means, modref_stds, modref_covs, full_covariance, prior_sampler, chain_stds, HMC_std_multiplier, explore_target, n_explore) 
    
    # Local exploration phase    
    newState_full = LocalExploration(State, Kernels, optimreference_round, modref_means, modref_stds, modref_covs, full_covariance, prior_sampler, chain_stds, HMC_std_multiplier, explore_target, n_explore)
    newState = newState_full.out
    ChainAcceptance = newState_full.ChainAcceptance

    newEnergy = potential.(newState, eachrow(Etas)) # -log([π_t_0(x^0), π_t_1(x^1), ..., π_t_N(x^N)]) : length N+1
    newEnergy1 = potential.(newState[2:end], eachrow(Etas[1:end-1, :])) # -log([π_t_0(x^1), π_t_1(x^2), ..., π_t_{N-1}(x^N)]) : length N
    newEnergy2 = potential.(newState[1:end-1], eachrow(Etas[2:end, :])) # -log([π_t_1(x^0), π_t_2(x^1), ..., π_t_N(x^{N-1})]) : length N
    newIndex = copy(Index)
    newLift = copy(Lift)

    # Communication phase
    # Compute acceptance probability
    Acceptance = acceptanceprobability(newEnergy, newEnergy1, newEnergy2)

    # Update Rejection
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