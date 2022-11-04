include("../src/setkernels.jl")

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