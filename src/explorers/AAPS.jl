""" 
$SIGNATURES 

The Apogee to Apogee Path Sampler (AAPS) by Sherlock et al. (2022). 

AAPS is a simple alternative to the No U-Turn Sampler (NUTS).
For a given starting position and momentum (x, v), AAPS explores forward and 
backward trajectories. The trajectories are divided into segments, with 
segments being separated by apogees in the energy landscape. 
The tuning parameter `K` defines the number of segments to explore. 
"""
@kwdef struct{T,D} AAPS
    """ 
    Leapfrog step size.
    """
    ϵ::Float64 = 1.0

    """  
    Maximum number of segments to explore.
    """ 
    K::Int = 5 

    """ 
    See details in AutoMALA. 
    """
    default_autodiff_backend::Symbol = :ForwardDiff # not used for Stan models

    """ 
    See details in AutoMALA.
    """
    adapt_pre_conditioning::Bool = true

    """ 
    See details in AutoMALA. 
    """
    estimated_target_std_deviations::T = nothing

    """ 
    Cache of the inverse mass matrix. 
    """
    inverse_mass_matrix::D = nothing
end

function adapt_explorer(explorer::AAPS, reduced_recorders, ...)
    if explorer.adapt_pre_conditioning
        estimated_target_variances = get_transformed_statistic(reduced_recorders, :singleton_variable, Variance)
        estimated_target_std_dev = sqrt.(estimated_target_variances)
        inverse_mass_matrix = Diagonal(inv.(estimated_target_variances))
    else
        estimated_target_std_dev = inverse_mass_matrix = nothing 
    end
    # todo: adapt ϵ and L 
    return AAPS(
        explorer.ϵ, explorer.K, explorer.default_autodiff_backend, 
        explorer.adapt_pre_conditioning, estimated_target_std_dev,
        inverse_mass_matrix
    )
end

step!(explorer::AAPS, replica, shared) = 
    step!(explorer, replica, shared, replica.state)

step!(explorer::AAPS, replica, shared, state::StanState) = 
    step!(explorer, replica, shared, state.unconstrained_parameters)

function step!(explorer::AAPS, replica, shared, state::AbstractVector)
    log_potential = find_log_potential(replica, shared.tempering, shared)
    _extract_commons_and_run_aaps!(explorer, replica, shared, log_potential, state)
end

function step!(explorer::AAPS, replica, shared, vi::DynamicPPL.TypedVarInfo)
    log_potential = find_log_potential(replica, shared.tempering, shared)
    state = DynamicPPL.getall(vi)
    _extract_commons_and_run_aaps!(explorer, replica, shared, log_potential, state)
    DynamicPPL.setall!(replica.state, state)
end

# Extract info common to all types of target and perform a step!()
function _extract_commons_and_run_aaps!(explorer::AAPS, replica, shared, log_potential, state::AbstractVector)
    log_potential_autodiff = ADgradient(
        explorer.default_autodiff_backend, log_potential, replica.recorders.buffers
    )      
    aaps!(
        replica.rng,
        explorer, 
        log_potential_autodiff,
        state, 
        replica.recorders, 
        replica.chain
    )
end

""" 
Main function for AAPS. Note that this implementation uses scheme (1) 
from the AAPS paper, which results in an acceptance probability of one.
""" 
function aaps!(
    rng::AbstractRNG,
    explorer::AAPS,
    target_log_potential,
    state::Vector,
    recorders,
    chain)
    dim   = length(state)
    r     = get_buffer(recorders.buffers, :aaps_momentum_buffer, dim)
    randn!(rng, r)
    lp0   = log_joint(target_log_potential, state, r)
    rtemp = copy(r)

    #= sample the original segment by expanding out forward/backward
    θ: parameter states (in Pigeons this is just the `state`, whereas the 
       original implementation had state.rng, state.θ, etc.) 
       Last position of the state in the segment (forward or backward).
    r: momentum. Last position of the momentum in the segment. 
    Wmax: use of Gumbel-max trick. At Wmax, θmax represents the state that should be 
       selected according to the chosen weighting function.
    θmax: the parameter value at Wmax.
    rmax: the momentum at Wmax.
    =#
    θfwd, rfwd, Wmaxf, θmaxf, rmaxf = sample_segment(explorer, state, rtemp, lp0, target_log_potential)
    rtemp = -copy(r) # change momentum direction to move backwards
    θbwd, rbwd, Wmaxb, θmaxb, rmaxb = sample_segment(explorer, state, rtemp, lp0, target_log_potential)

    if Wmaxf > Wmaxb # forward move has been accepted in proposal
        θmax = θmaxf
        rmax = rmaxf
        Wmax = Wmaxf
    else # backward move 
        θmax = θmaxb
        rmax = rmaxb
        Wmax = Wmaxb
    end
  
    # sample subsequent segments by continuing from the previous endpoints
    for _ in 1:(explorer.K-1)
        if isnan(explorer.ϵ)
            error("aaps!: step size is NaN, try reducing Δ") # todo
        end

        if rand(rng, Bool)
            # extend the forward trajectory
            # (avoids specifying in advance how many times we move forward/backward)
            state = θfwd
            rtemp = rfwd
            θfwd, rfwd, Wmax_2, θmax_2, rmax_2 = 
                sample_segment(explorer, state, rtemp, lp0, target_log_potential)
        else  
            # extend the backward trajectory
            state = θbwd
            rtemp = rbwd
            θbwd, rbwd, Wmax_2, θmax_2, rmax_2 = 
                sample_segment(explorer, state, rtemp, lp0, target_log_potential)
        end
        if Wmax_2 > Wmax
            θmax = θmax_2
            rmax = rmax_2
            Wmax = Wmax_2
        end
    end  
    # set the final state and update step size
    state = copy(θmax)
    r = copy(rmax)
end

""" 
Sample a segment of the trajectory until an apogee is reached. 
"""
function sample_segment(
    explorer::AAPS,
    state::Vector,
    r::Vector,
    lp0::Float64,
    target_log_potential)
    θ0    = copy(state)
    rtemp = copy(r)
    θmax  = copy(state)
    rmax  = copy(r)
    g0    = grad_log_potential(state, model, cv) # todo 
    _, g0 = LogDensityProblems.logdensity_and_gradient(target_log_potential, state) 
    lp    = log_joint(target_log_potential, state, r)
    Wmax  = lp + rand(rng, Gumbel()) # todo: why do we repeat this calculation?
  
    # propagate forward, checking for apogee, tracking stats, keeping track of next state using gumbel-max trick
    s0 = sign(dot(rtemp, -g0))
    while true
        leapfrog!(explorer, state, rtemp, model, cv)
        _, g0 = LogDensityProblems.logdensity_and_gradient(target_log_potential, state) 
        s = sign(dot(rtemp, -g0))
        if s != s0
            break # todo: This seems to define a segment as a place where the sign changes 
            # i.e., either a local minimum or maximum. 
            # However, the "apogee" in AAPS clearly indicates that we should only 
            # define new segments when we reach a maximum.
        end
        lp = log_joint(target_log_potential, state, rtemp)
        W = lp + rand(rng, Gumbel())
        if W > Wmax
            Wmax = W
            θmax = state
            rmax = rtemp
        end
    end
    θfwd, rfwd = copy(state), copy(rtemp)
    state = θ0
    
    return θfwd, rfwd, Wmax, θmax, rmax
end


function explorer_recorder_builders(explorer::AAPS)
    result = [explorer_acceptance_pr, explorer_n_steps, buffers]
    if explorer.adapt_pre_conditioning 
        push!(result, _transformed_online) # mass matrix adaptation
    end
    return result
end

###############################################################################
# The Pigeons implementation of AAPS is based on code by 
# Naitong Chen and Trevor Campbell (2023), reused with their permission.
# Note:
# y(x) := M^{-1/2}x => x(y) = M^{1/2}y
# x ~ p_x => p_y(y) = p_x(M^{1/2}y) |detM|^{1/2} propto p_x(M^{1/2}y) 
# => grad{log p_y}(y) = M^{1/2} grad(log p_x)(M^{1/2}y) 
# for p ~ N(0,M), the leapfrog is
#   p*(x,p)   = p + (eps/2)grad(x)
#   x'(x,p*)  = x + epsM^{-1}p*
#   p'(x',p*) = p* + (eps/2)grad(x')
# if y = M^{-1/2}p => y ~ N(0,I) and p = M^{1/2}y.
#   y*(x,y)   = M^{1/2}y + (eps/2)grad(x)
#   x'(x,y*)  = x + epsM^{-1}y*
#   y'(x',y*) = y* + (eps/2)grad(x')
###############################################################################