struct PT_output
    states
    final_states
    energies
    indices
    lifts
    rejections
    local_barriers
    global_barriers
    norm_constant
    schedules
    roundtrips
    roundtriprates
    chain_acceptance_rates
    N
    potential
    count
    nscan
    dim_x
    modref_means
    modref_stds
    modref_covs
    end_time
end




"""
    NRPT(V_0, V_1, initial_state, ntotal, N)

Non-reversible parallel tempering (NRPT).

# Arguments
 - `potential`: Function with three arguments (x, η, params) that returns a 'double'.
   'x' is the point at which the log-density V_0(x; params=params) * η[1] + V_1(x) * η[2] is evaluated,
   where V_0 is the negative log density of the reference and V_1 is the negative
   log density of the target.
 - `initial_state`: Matrix of initial states for all N+1 chains. Dimensions: (N+1) x (dim_x).
 - `ntotal`: Total number of scans/iterations.
 - `N`: The total number of chains is N+1.
 - `optimreference`: Whether the reference distribution is to be optimized.
 - `maxround`: Maximum number of rounds for tuning.
 - `fulltrajectory`: Controls whether to keep track of all 'states', 'indices', 'energies', and 'lifts'.
 - `ϕ`: (Partially removed. Useful for constructing non-linear paths.)
 - `resolution`: Resolution of the output for the estimates of the local communication barrier.
 - `prior_sampler`: User may supply an efficient sampler that can obtain
    samples from the *prior* / original reference distribution.
 - `optimreference_start`: On which tuning round to start optimizing the reference distribution.
 - `full_covariance`: Controls whether to use a mean-field approximation for the modified
    reference (false) or a full covariance matrix (true)
 - `winsorize`: Whether or not to use a winsorized/trimmed mean when estimating
 the parameters of the variational reference
 - `two_references`: Whether to run two PT chains in parallel with two different references:
    prior and variational reference. Note that with this setting there are 2*(N+1) chains in total.
 - `modref_means_start`: Starting values for modref_means
 - `modref_stds_start`: Starting values for modref_stds
 - `n_explore`: Number of exploration steps to take before considering a communication swap
"""
function NRPT(V_0,
    V_1,
    initial_state::Vector{Vector{T}} where T <: Real,
    ntotal::Int,
    N::Int;
    optimreference::Bool = true,
    maxround::Int = floor(Int, log2(ntotal))-2,
    fulltrajectory::Bool = true,
    ϕ = [0.5 0.5],
    resolution::Int = 101,
    prior_sampler = nothing,
    optimreference_start::Int = 4,
    full_covariance::Bool = false,
    winsorize::Bool = false,
    two_references::Bool = false,
    modref_means_start = nothing,
    modref_stds_start = nothing,
    n_explore::Int = 1)

    # Collect input information
    input_info = (
        V_0                     = V_0,
        V_1                     = V_1,
        initial_state            = initial_state,
        ntotal                  = ntotal,
        N                       = N,
        optimreference          = optimreference,
        maxround                = maxround,
        fulltrajectory          = fulltrajectory,
        ϕ                     = ϕ,
        resolution              = resolution,
        prior_sampler           = prior_sampler,
        optimreference_start    = optimreference_start,
        full_covariance         = full_covariance,
        winsorize               = winsorize,
        two_references          = two_references,
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
    old_potential = potential

    dim_x = length(initial_state[1]) # Dimension of x
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

    rejections = zeros(N,maxround+1) # Chain communication rejection rates (exclude the last chain)
    local_barriers = zeros(resolution,maxround+1)
    global_barriers = zeros(maxround+1) # Include a global communication barrier estimate for each round
    norm_constant = zeros(maxround+1)
    schedules = zeros(N+1,maxround+2) # Annealing schedules
    schedules[:,1] = collect(range(0, 1, length = N+1)) # Start with an equally spaced schedule
    roundtrips = zeros(maxround+1) # Number of round trips
    roundtriprates = zeros(maxround+1)
    chain_acceptance_rates = [Vector{Float64}(undef, N+1) for _ in 1:(maxround+1)]

    if two_references
        rejections_old = zeros(N,maxround+1)
        local_barriers_old = zeros(resolution,maxround+1)
        global_barriers_old = zeros(maxround+1)
        norm_constant_old = zeros(maxround+1)
        schedules_old = zeros(N+1,maxround+2)
        schedules_old[:,1] = collect(range(0, 1, length = N+1))
        roundtrips_old = zeros(maxround+1)
        roundtriprates_old = zeros(maxround+1)
        chain_acceptance_rates_old = [Vector{Float64}(undef, N+1) for _ in 1:(maxround+1)]
    end


    # Initialize states
    states = Vector{typeof(initial_state)}(undef,1) # Store the (current) state: 1 [N+1 [dim_x]].
    # Later becomes of size: previous_nscan [N+1 [dim_x]] (!fulltrajectory), or: all_previous_nscans [N+1 [dim_x]]
    states[1] = initial_state # N+1 [ dim_x]
    final_states = initial_state

    etas = computeetas(ϕ, schedules[:,1]) # If ϕ = [0.5 0.5], returns a linear path
    energies = Vector{typeof(potential.(initial_state, eachrow(etas)))}(undef,1)
    energies[1] = potential.(initial_state, eachrow(etas)) # Current energy for each chain

    indices = Vector{typeof([i for i ∈ 1:1:N+1])}(undef,1)
    indices[1] = [i for i ∈ 1:1:N+1] # 1, 2, ..., N+1

    lifts = Vector{typeof([2(i%2)-1 for i ∈ 1:N+1])}(undef,1)
    lifts[1] = [2(i%2)-1 for i ∈ 1:N+1] # -1 if even chain, +1 if odd chain

    if two_references
        states_old = Vector{typeof(initial_state)}(undef,1)
        states_old[1] = initial_state
        final_states_old = initial_state

        etas_old = computeetas(ϕ, schedules_old[:,1])
        energies_old = Vector{typeof(potential.(initial_state, eachrow(etas)))}(undef,1)
        energies_old[1] = old_potential.(initial_state, eachrow(etas_old))

        indices_old = Vector{typeof([i for i ∈ 1:1:N+1])}(undef,1)
        indices_old[1] = [i for i ∈ 1:1:N+1]

        lifts_old = Vector{typeof([2(i%2)-1 for i ∈ 1:N+1])}(undef,1)
        lifts_old[1] = [2(i%2)-1 for i ∈ 1:N+1]
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


    for round in 1:maxround+1
        nscan *= 2 # Double the number of scans

        if round == maxround + 1
            nscan = ntotal - ntune # Use remaining scans in the last round
        end

        if !two_references
            PT = deo(potential, states[end], indices[end], lifts[end], schedules[:,round],
                     ϕ, nscan, N, resolution, optimreference_round, modref_means,
                     modref_stds, modref_covs, full_covariance, prior_sampler, n_explore)
        else # Run two versions of PT in parallel
            PT = deo(potential, states[end], indices[end], lifts[end], schedules[:,round],
                     ϕ, nscan, N, resolution, optimreference_round, modref_means,
                     modref_stds, modref_covs, full_covariance, prior_sampler, n_explore)
            PT_old = deo(old_potential, states_old[end], indices_old[end], lifts_old[end],
                         schedules_old[:,round], ϕ, nscan, N, resolution, false,
                         modref_means, modref_stds, modref_covs, full_covariance,
                         prior_sampler, n_explore)
        end
        ntune += nscan

        ###  Update monitoring/diagnostics
        rejections[:,round] = PT.Rejection # 'PT' is a "list"-like object
        local_barriers[:,round] = PT.localbarrier
        global_barriers[round] = PT.globalbarrier
        norm_constant[round] = PT.norm_constant
        schedules[:,round+1] = PT.schedule_update
        roundtrips[round] = PT.RoundTrip
        roundtriprates[round] = PT.roundtriprate
        chain_acceptance_rates[round] = PT.chain_acceptance_rate

        if two_references
            rejections_old[:,round] = PT_old.Rejection
            local_barriers_old[:,round] = PT_old.localbarrier
            global_barriers_old[round] = PT_old.globalbarrier
            norm_constant_old[round] = PT_old.norm_constant
            schedules_old[:,round+1] = PT_old.schedule_update
            roundtrips_old[round] = PT_old.RoundTrip
            roundtriprates_old[round] = PT_old.roundtriprate
            chain_acceptance_rates_old[round] = PT_old.chain_acceptance_rate
        end

        ### Update states
        if fulltrajectory # Store all information
            states = vcat(states, PT.states)
            energies = vcat(energies, PT.energies)
            indices = vcat(indices, PT.indices)
            lifts = vcat(lifts, PT.lifts)
            if two_references
                states_old = vcat(states_old, PT_old.states)
                energies_old = vcat(energies_old, PT_old.energies)
                indices_old = vcat(indices_old, PT_old.indices)
                lifts_old = vcat(lifts_old, PT_old.lifts)
            end
        else # Keep only the latest information
            states = PT.states
            energies = PT.energies
            indices = PT.indices
            lifts = PT.lifts
            if two_references
                states_old = PT_old.states
                energies_old = PT_old.energies
                indices_old = PT_old.indices
                lifts_old = PT_old.lifts
            end
        end

        ### Perform optimization
        if optimreference && (round >= optimreference_start) && (round <= maxround) # Optimize the reference
            optimreference_round = true

            if !fixed_variational_ref # Tune the reference
                if !two_references
                    statesToConsider = map((x) -> PT.states[x][end], 1:nscan) # Take 'nscan' scans from the target
                else # Merge the various states into one long vector
                    statesToConsider = vcat(map((x) -> PT.states[x][end], 1:nscan), map((x) -> PT_old.states[x][end], 1:nscan))
                end
                # statesToConsider is now a vector of length nscan (or 2*nscan) containing vectors of length dim_x
                if winsorize
                    modref_means = winsorized_mean(statesToConsider)
                else
                    modref_means = mean(statesToConsider)
                end
                println("Modified reference means = $modref_means")

                if !full_covariance
                    if winsorize
                        modref_stds = winsorized_std(statesToConsider)
                    else
                        modref_stds = std(statesToConsider) # Mean-field approximation
                    end
                    println("Modified reference stds = $modref_stds")
                else
                    if winsorize
                        error("Full covariance matrix Winsorization not implemented.")
                    else
                        modref_covs = cov(statesToConsider) # Full covariance matrix approximation
                        modref_covs_inv = inv(modref_covs) # Cache the matrix inverse for evaluation of the potential
                    end
                    println("Modified reference covs = $modref_covs")
                end
            end # Otherwise, we have already specified the variational reference means and covariances

            # Update definition of 'potential'
            new_potential2(x, η) = new_potential(x, η, modref_means, modref_stds,
                                                 modref_covs_inv, V_1, full_covariance)
            potential = new_potential2
        end

        if (nscan == 2^min(maxround, 11)) # Old code. Doesn't do anything important.
            count = ntune
        end

        final_states = PT.states
        nscan_old = nscan
        if two_references
            final_states_old = PT_old.states
        end
    end

    out = PT_output(states, final_states, energies, indices, lifts, rejections,
                    local_barriers, global_barriers, norm_constant, schedules,
                    roundtrips, roundtriprates, chain_acceptance_rates, N, potential,
                    count, nscan, dim_x, modref_means, modref_stds,
                    modref_covs, Dates.now())

    if two_references
        out_new = out
        out_old = PT_output(states, final_states, energies, indices, lifts, rejections,
                            local_barriers, global_barriers, norm_constant, schedules,
                            roundtrips, roundtriprates, chain_acceptance_rates, N, potential,
                            count, nscan, dim_x, nothing, nothing, nothing,
                            Dates.now())
        out = (out_new = out_new, out_old = out_old, input_info = input_info)
    end

    return out
end
