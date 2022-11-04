#' Non-reversible parallel tempering (NRPT)
#'
#' The main NRPT and variational PT function
#'
#' @param potential Function with three arguments (x, η, params) that returns a 'double'. 
#'   'x' is the point at which the log-density V_0(x; params=params) * η[1] + V_1(x) * η[2] is evaluated, 
#'   where V_0 is the negative log density of the reference and V_1 is the negative log density of the target.
#' @param InitialState Matrix of initial states for all N+1 chains. Dimensions: (N+1) x (dim_x).
#' @param ntotal Total number of scans/iterations.
#' @param N The total number of chains is N+1.
#' @param pars Any additional parameters that should be sent to 'potential'.
#' @param optimreference Controls whether the reference distribution is to be optimized.
#' @param K (Removed.)
#' @param MaxRound Maximum number of rounds for tuning.
#' @param fulltrajectory Controls whether to keep track of all 'States', 'Indices', 'Energies', and 'Lifts'.
#' @param optimpath Controls whether the path is to be optimized. Not implemented yet.
#' @param gradsamps (Removed.)
#' @param gradientfn (Removed.)
#' @param Phi (Partially removed. Useful for constructing non-linear paths.)
#' @param verbose Controls whether to print all of the output.
#' @param resolution Resolution of the output for the estimates of the local communication barrier. 
#' @param prior_sampler User may supply an efficient sampler that can obtain samples from the *prior* / original reference distribution.
#' @param optimreference_start On which tuning round to start optimizing the reference distribution.
#' @param optimHMC_start On which tuning round to start tuning the HMC exploration kernel
#' @param full_covariance Controls whether to use a mean-field approximation for the modified reference (false) or a full covariance matrix (true)
#' @param Winsorize Whether or not to use a Winsorized/trimmed mean when estimating the parameters of the variational reference
#' @param HMC_std_multiplier Multiply the estimated chain standard deviations by this factor (can be a vector)
#' @param L Number of leapfrog steps
#' @param two_references Whether to run two PT chains in parallel with two different references: prior and variational reference. Note that with this setting there are 2*(N+1) chains in total.
#' @param explore_target Whether to use local exploration in the target chain. (Default is true, but set it to false if you want to test an accept/reject algorithm.)
#' @param modref_means_start Starting values for modref_means
#' @param modref_stds_start Starting values for modref_stds
#' @param n_explore Number of exploration steps to take before considering a communication swap
#'
#' @export
function nrpt(V_0, V_1, InitialState, ntotal, N; 
    optimreference = true,
    K = 100,
    MaxRound = floor(Int, log2(ntotal))-2,
    fulltrajectory = true, 
    optimpath = true,
    gradsamps = 100,
    gradientfn = nothing,
    Phi = [0.5 0.5],
    verbose = false,
    resolution = 101,
    prior_sampler = nothing,
    optimreference_start = 4,
    optimHMC_start = 4,
    full_covariance = false,
    Winsorize = false,
    HMC_std_multiplier = nothing,
    L = 10,
    two_references = false,
    explore_target = true,
    modref_means_start = nothing,
    modref_stds_start = nothing,
    n_explore = 1)

    # Collect input information
    input_info = (
        V_0                     = V_0, 
        V_1                     = V_1, 
        InitialState            = InitialState, 
        ntotal                  = ntotal, 
        N                       = N, 
        optimreference          = optimreference,
        K                       = K,
        MaxRound                = MaxRound,
        fulltrajectory          = fulltrajectory,
        optimpath               = optimpath,
        gradsamps               = gradsamps,
        gradientfn              = gradientfn,
        Phi                     = Phi,
        verbose                 = verbose,
        resolution              = resolution,
        prior_sampler           = prior_sampler,
        optimreference_start    = optimreference_start,
        optimHMC_start          = optimHMC_start,
        full_covariance         = full_covariance,
        Winsorize               = Winsorize,
        HMC_std_multiplier      = HMC_std_multiplier,
        L                       = L,
        two_references          = two_references,
        explore_target          = explore_target,
        modref_means_start      = modref_means_start,
        modref_stds_start       = modref_stds_start,
        n_explore               = n_explore,
        start_time              = Dates.now())
    
    # Initialize monitoring/diagnostics
    function potential(x, η)
        if η[1] == 1.0
            out = V_0(x) # Fixes issues if π_0 and π_1 have different supports: a*1 + 0*Inf = NaN in Julia
        elseif η[2] == 1.0
            out = V_1(x)
        else
            out = V_0(x) * η[1] + V_1(x) * η[2]
        end
    end
    old_potential = potential # This just points to the *original definition* of "potential()". Even if "potential()" changes, "old_potential()" stays the same!

    dim_x = length(InitialState[1]) # Dimension of x
    if (!isnothing(modref_means_start)) && (!isnothing(modref_stds_start))
        fixed_variational_ref = true
    else
        fixed_variational_ref = false
    end
    if isnothing(modref_means_start)
        modref_means = Vector{Float64}(undef, dim_x)
    else
        modref_means = modref_means_start
    end
    if isnothing(modref_stds_start)
        modref_stds = Vector{Float64}(undef, dim_x)
    else
        modref_stds = modref_stds_start
    end
    modref_covs = Matrix{Float64}(undef, dim_x, dim_x)
    modref_covs_inv = similar(modref_covs)
    chain_stds = Vector{typeof(modref_stds)}(undef, N+1) # For tuning HMC exploration only. Initialized below.
    
    Rejections = zeros(N,MaxRound+1) # Chain communication rejection rates (exclude the last chain)
    LocalBarriers = zeros(resolution,MaxRound+1)
    GlobalBarriers = zeros(MaxRound+1) # Include a global communication barrier estimate for each round
    NormalizingConstant = zeros(MaxRound+1)
    Schedules = zeros(N+1,MaxRound+2) # Annealing schedules
    Schedules[:,1] = collect(range(0, 1, length = N+1)) # Start with an equally spaced schedule
    RoundTrips = zeros(MaxRound+1) # Number of round trips
    RoundTripRates = zeros(MaxRound+1)
    ChainAcceptanceRates = [Vector{Float64}(undef, N+1) for _ in 1:(MaxRound+1)]
    
    if two_references
        Rejections_old = zeros(N,MaxRound+1) 
        LocalBarriers_old = zeros(resolution,MaxRound+1)
        GlobalBarriers_old = zeros(MaxRound+1) 
        NormalizingConstant_old = zeros(MaxRound+1)
        Schedules_old = zeros(N+1,MaxRound+2) 
        Schedules_old[:,1] = collect(range(0, 1, length = N+1)) 
        RoundTrips_old = zeros(MaxRound+1) 
        RoundTripRates_old = zeros(MaxRound+1)
        ChainAcceptanceRates_old = [Vector{Float64}(undef, N+1) for _ in 1:(MaxRound+1)]
    end

    if isnothing(HMC_std_multiplier)
        HMC_std_multiplier = [1.0 for _ in 1:(N+1)]
    end


    # Initialize states
    States = Vector{typeof(InitialState)}(undef,1) # Store the (current) state: 1 [N+1 [dim_x]]. 
    # Later becomes of size: previous_nscan [N+1 [dim_x]] (!fulltrajectory), or: all_previous_nscans [N+1 [dim_x]]
    States[1] = InitialState # N+1 [ dim_x]
    FinalStates = InitialState

    Etas = computeEtas(Phi, Schedules[:,1]) # If Phi = [0.5 0.5], returns a linear path
    Energies = Vector{typeof(potential.(InitialState, eachrow(Etas)))}(undef,1)
    Energies[1] = potential.(InitialState, eachrow(Etas)) # Current energy for each chain

    Indices = Vector{typeof([i for i ∈ 1:1:N+1])}(undef,1)
    Indices[1] = [i for i ∈ 1:1:N+1] # 1, 2, ..., N+1

    Lifts = Vector{typeof([2(i%2)-1 for i ∈ 1:N+1])}(undef,1)
    Lifts[1] = [2(i%2)-1 for i ∈ 1:N+1] # -1 if even chain, +1 if odd chain

    if two_references
        States_old = Vector{typeof(InitialState)}(undef,1)
        States_old[1] = InitialState
        FinalStates_old = InitialState

        Etas_old = computeEtas(Phi, Schedules_old[:,1])
        Energies_old = Vector{typeof(potential.(InitialState, eachrow(Etas)))}(undef,1)
        Energies_old[1] = old_potential.(InitialState, eachrow(Etas_old))

        Indices_old = Vector{typeof([i for i ∈ 1:1:N+1])}(undef,1)
        Indices_old[1] = [i for i ∈ 1:1:N+1]

        Lifts_old = Vector{typeof([2(i%2)-1 for i ∈ 1:N+1])}(undef,1)
        Lifts_old[1] = [2(i%2)-1 for i ∈ 1:N+1]
    end

    # Initialize to MVN(0, I)
    for j in 1:N+1
        chain_stds[j] = [1.0 for i in 1:dim_x]
    end


    # Initial samples (with tuning)
    nscan = 1 # Number of scans to use for *this round*
    nscan_old = 0 # Number of scans used in the previous round 
    ntune = 1 # Number of scans used for tuning *so far*! (Why does it start at 1 instead of 0?)
    count = 0 # Maximum number of scans used for tuning
    optimreference_round = false
    
    # Define 'new_potential' function
    function new_potential(x, η, modref_means, modref_stds, modref_covs_inv, V_1, full_covariance)
        if !full_covariance # Mean-field approximation
            out = 0.0
            for j in 1:length(x)
                out += 0.5 * (x[j] - modref_means[j]) * (1.0/modref_stds[j]^2) * (x[j] - modref_means[j])
            end
        else # Full covariance matrix
            out = 0.5 * (x - modref_means)' * modref_covs_inv * (x - modref_means)
        end
        
        if η[1] == 1.0
            final_out = out
        elseif η[2] == 1.0
            final_out = V_1(x)
        else
            final_out = out * η[1] + V_1(x) * η[2]
        end
        return final_out
    end


    for round in 1:MaxRound+1
        nscan *= 2 # Double the number of scans
        
        if round == MaxRound + 1
            nscan = ntotal - ntune # Use remaining scans in the last round
        end

        if verbose # Include timing information
            if !two_references
                @time PT = deo(potential, States[end], Indices[end], Lifts[end], Schedules[:,round], Phi, nscan, N, verbose, resolution, optimreference_round, modref_means, modref_stds, modref_covs, full_covariance, prior_sampler, chain_stds, HMC_std_multiplier, L, explore_target, n_explore)
            else # Run two versions of PT in parallel
                @time PT = deo(potential, States[end], Indices[end], Lifts[end], Schedules[:,round], Phi, nscan, N, verbose, resolution, optimreference_round, modref_means, modref_stds, modref_covs, full_covariance, prior_sampler, chain_stds, HMC_std_multiplier, L, explore_target, n_explore)
                @time PT_old = deo(old_potential, States_old[end], Indices_old[end], Lifts_old[end], Schedules_old[:,round], Phi, nscan, N, verbose, resolution, false, modref_means, modref_stds, modref_covs, full_covariance, prior_sampler, chain_stds, HMC_std_multiplier, L, explore_target, n_explore)
            end
        else # Run DEO (deterministic even-odd)
            if !two_references
                PT = deo(potential, States[end], Indices[end], Lifts[end], Schedules[:,round], Phi, nscan, N, verbose, resolution, optimreference_round, modref_means, modref_stds, modref_covs, full_covariance, prior_sampler, chain_stds, HMC_std_multiplier, L, explore_target, n_explore)
            else # Run two versions of PT in parallel
                PT = deo(potential, States[end], Indices[end], Lifts[end], Schedules[:,round], Phi, nscan, N, verbose, resolution, optimreference_round, modref_means, modref_stds, modref_covs, full_covariance, prior_sampler, chain_stds, HMC_std_multiplier, L, explore_target, n_explore)
                PT_old = deo(old_potential, States_old[end], Indices_old[end], Lifts_old[end], Schedules_old[:,round], Phi, nscan, N, verbose, resolution, false, modref_means, modref_stds, modref_covs, full_covariance, prior_sampler, chain_stds, HMC_std_multiplier, L, explore_target, n_explore)
            end
        end
        ntune += nscan

        ###  Update monitoring/diagnostics
        Rejections[:,round] = PT.Rejection # 'PT' is a "list"-like object
        LocalBarriers[:,round] = PT.LocalBarrier
        GlobalBarriers[round] = PT.GlobalBarrier
        NormalizingConstant[round] = PT.NormalizingConstant
        Schedules[:,round+1] = PT.ScheduleUpdate
        RoundTrips[round] = PT.RoundTrip
        RoundTripRates[round] = PT.RoundTripRate
        ChainAcceptanceRates[round] = PT.ChainAcceptanceRate

        if two_references
            Rejections_old[:,round] = PT_old.Rejection
            LocalBarriers_old[:,round] = PT_old.LocalBarrier
            GlobalBarriers_old[round] = PT_old.GlobalBarrier
            NormalizingConstant_old[round] = PT_old.NormalizingConstant
            Schedules_old[:,round+1] = PT_old.ScheduleUpdate
            RoundTrips_old[round] = PT_old.RoundTrip
            RoundTripRates_old[round] = PT_old.RoundTripRate
            ChainAcceptanceRates_old[round] = PT_old.ChainAcceptanceRate
        end

        ### Update states
        if fulltrajectory # Store all information
            States = vcat(States, PT.States)
            Energies = vcat(Energies, PT.Energies)
            Indices = vcat(Indices, PT.Indices)
            Lifts = vcat(Lifts, PT.Lifts)
            if two_references
                States_old = vcat(States_old, PT_old.States)
                Energies_old = vcat(Energies_old, PT_old.Energies)
                Indices_old = vcat(Indices_old, PT_old.Indices)
                Lifts_old = vcat(Lifts_old, PT_old.Lifts)
            end
        else # Keep only the latest information
            States = PT.States
            Energies = PT.Energies
            Indices = PT.Indices
            Lifts = PT.Lifts
            if two_references
                States_old = PT_old.States
                Energies_old = PT_old.Energies
                Indices_old = PT_old.Indices
                Lifts_old = PT_old.Lifts
            end
        end

        ### Perform optimization
        if optimreference && (round >= optimreference_start) && (round <= MaxRound) # Optimize the reference distribution
            optimreference_round = true

            if !fixed_variational_ref # Tune the variational reference
                if !two_references
                    statesToConsider = map((x) -> PT.States[x][end], 1:nscan) # Take 'nscan' scans from the target distribution.
                else # Merge the various states into one long vector
                    statesToConsider = vcat(map((x) -> PT.States[x][end], 1:nscan), map((x) -> PT_old.States[x][end], 1:nscan))
                end
                # statesToConsider is now a vector of length nscan (or 2*nscan) containing vectors of length dim_x
                if Winsorize
                    modref_means = Winsorized_mean(statesToConsider)
                else
                    modref_means = mean(statesToConsider)
                end
                println("Modified reference means = $modref_means")
                
                if !full_covariance
                    if Winsorize
                        modref_stds = Winsorized_std(statesToConsider)
                    else
                        modref_stds = std(statesToConsider) # Mean-field approximation
                    end
                    println("Modified reference stds = $modref_stds")
                else
                    if Winsorize
                        error("Full covariance matrix Winsorization not implemented.")
                    else
                        modref_covs = cov(statesToConsider) # Full covariance matrix approximation
                        modref_covs_inv = inv(modref_covs) # Cache the matrix inverse for evaluation of the potential
                    end
                    println("Modified reference covs = $modref_covs")
                end
            end # Otherwise, we have already specified the variational reference means and covariances

            # Update definition of 'potential'
            new_potential2(x, η) = new_potential(x, η, modref_means, modref_stds, modref_covs_inv, V_1, full_covariance)
            potential = new_potential2
        end

        if (nscan == 2^min(MaxRound, 11)) # Old code. Doesn't do anything important.
            count = ntune
        end

        if verbose && (round <= MaxRound)
            println("Finished Round $round with $nscan scans")
        elseif verbose && (round == MaxRound+1)
            println("Finished Final Round $round with $nscan scans")
        end

        FinalStates = PT.States
        nscan_old = nscan
        if two_references
            FinalStates_old = PT_old.States
        end
    end
    
    out = (
        States              = States,
        FinalStates         = FinalStates,
        Energies            = Energies,
        Indices             = Indices,
        Lifts               = Lifts,
        Rejections          = Rejections,
        LocalBarriers       = LocalBarriers,
        GlobalBarriers      = GlobalBarriers,
        NormalizingConstant = NormalizingConstant,
        Schedules           = Schedules,
        RoundTrips          = RoundTrips,
        RoundTripRates      = RoundTripRates,
        ChainAcceptanceRates = ChainAcceptanceRates,
        N                   = N,
        potential           = potential,
        count               = count,
        nscan               = nscan,
        dim_x               = dim_x,
        input_info          = input_info,
        modref_means        = modref_means,
        modref_stds         = modref_stds,
        modref_covs         = modref_covs,
        end_time            = Dates.now()
    )

    if two_references
        out_new = out
        out_old = (
            States              = States_old,
            FinalStates         = FinalStates_old,
            Energies            = Energies_old,
            Indices             = Indices_old,
            Lifts               = Lifts_old,
            Rejections          = Rejections_old,
            LocalBarriers       = LocalBarriers_old,
            GlobalBarriers      = GlobalBarriers_old,
            NormalizingConstant = NormalizingConstant_old,
            Schedules           = Schedules_old,
            RoundTrips          = RoundTrips_old,
            RoundTripRates      = RoundTripRates_old,
            ChainAcceptanceRates = ChainAcceptanceRates_old,
            N                   = N,
            potential           = old_potential,
            count               = count,
            nscan               = nscan,
            dim_x               = dim_x,
            input_info          = input_info
        )
        out = (out_new = out_new, out_old = out_old, input_info = input_info)
    end

    # Return all relevant information
    return out
end