""" 
$SIGNATURES 

The Apogee to Apogee Path Sampler (AAPS) by Sherlock et al. (2022). 

AAPS is a simple alternative to the No U-Turn Sampler (NUTS).
For a given starting position and momentum (x, v), AAPS explores forward and 
backward trajectories. The trajectories are divided into segments, with 
segments being separated by apogees in the energy landscape. 
The tuning parameter `L` defines the number of segments to explore. 
"""
@kwdef struct{T,D} AAPS
    """ 
    Leapfrog step size.
    """
    ϵ::Float64 = 1.0

    """  
    Maximum number of segments to explore (not counting the initial one).
    """ 
    L::Int = 5 

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
        explorer.ϵ, explorer.L, explorer.default_autodiff_backend, 
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
    r: momentum  
    W: 
    rmax: 
    m: 
    m2: 
    n: 
    =#
    θfwd, rfwd, Wmaxf, θmaxf, rmaxf, mf, m2f, nf = sample_segment(explorer, state, rtemp, lp0, target_log_potential)
    rtemp = -copy(r) # change momentum direction to move backwards
    θbwd, rbwd, Wmaxb, θmaxb, rmaxb, mb, m2b, nb = sample_segment(explorer, state, rtemp, lp0, target_log_potential)

    if Wmaxf > Wmaxb
        θmax = θmaxf
        rmax = rmaxf
        Wmax = Wmaxf
    else # Wmaxb >= Wmaxf
        θmax = θmaxb
        rmax = rmaxb
        Wmax = Wmaxb
    end
    m = mf + mb
    m2 = m2f + m2b
    n = nf + nb
  
    # sample subsequent segments by continuing from the previous endpoints
    for _ in 1:(explorer.L-1)
        if isnan(explorer.ϵ)
            error("aaps!: step size is NaN, try reducing Δ")
        end

        if rand(rng, Bool)
            # extend the forward trajectory
            state.θ = θfwd
            rtemp = rfwd
            θfwd, rfwd, Wmax′, θmax′, rmax′, m′, m2′, n′ = 
                sample_segment(explorer, state, rtemp, lp0, target_log_potential)
        else  
            # extend the backward trajectory
            state.θ = θbwd
            rtemp = rbwd
            θbwd, rbwd, Wmax′, θmax′, rmax′, m′, m2′, n′ = 
                sample_segment(explorer, state, rtemp, lp0, target_log_potential)
        end
        if Wmax′ > Wmax
            θmax = θmax′
            rmax = rmax′
            Wmax = Wmax′
        end
        m += m′
        m2 += m2′
        n += n′
    end  
    # set the final state and update step size
    state.θ = copy(θmax)
    r = copy(rmax)
end

# todo (according to Miguel)
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
    g0    = grad_log_potential(state, model, cv)
    lp    = joint_log_potential(state, r, model, cv)
    Wmax  = lp + rand(rng, Gumbel())
    m     = exp(lp - lp0)
    m2    = exp(2*(lp - lp0))
    n     = 1
  
    # propagate forward, checking for apogee, tracking stats, keeping track of next state using gumbel-max trick
    s0 = sign(dot(rtemp, -g0))
    while true
        leapfrog!(explorer, state, rtemp, model, cv)
        s = sign(dot(rtemp, -grad_log_potential(state, model, cv)))
        if s != s0
            break
        end
        n += 1
        lp = joint_log_potential(state, rtemp, model, cv)
        m += exp(lp - lp0)
        m2 += exp(2*(lp - lp0))
        W = lp + rand(rng, Gumbel())
        if W > Wmax
            Wmax = W
            θmax = state.θ
            rmax = rtemp
        end
    end
    θfwd, rfwd = copy(state.θ), copy(rtemp)
    state.θ = θ0
    
    return θfwd, rfwd, Wmax, θmax, rmax, m, m2, n
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