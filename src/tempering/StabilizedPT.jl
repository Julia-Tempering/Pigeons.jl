""" 
Stabilized Variational Parallel Tempering as described in  
[Surjanovic et al., 2022](https://arxiv.org/abs/2206.00080).

Fields:
$FIELDS
"""
@auto struct StabilizedPT
    """ 
    The fixed leg of stabilized PT. 
    Contains a [`path`](@ref), [`Schedule`](@ref), [`log_potentials`](@ref), 
    and [`communication_barriers`](@ref).
    [`swap_graphs`](@ref) is also included but is overwritten by this struct's [`swap_graphs`](@ref).
    """
    fixed_leg::NonReversiblePT
    
    """ The variational leg of stabilized PT. """
    variational_leg::NonReversiblePT
    
    """ A [`swap_graphs`](@ref) spanning both legs. """
    swap_graphs

    """ The [`log_potentials`](@ref). """
    log_potentials

    """ An [`Indexer`](@ref) mapping between global indices and leg-specific indices. """
    indexer
end


""" 
$SIGNATURES 

Parallel tempering with a variational reference described in 
[Surjanovic et al., 2022](https://arxiv.org/abs/2206.00080).
"""
function StabilizedPT(inputs::Inputs)
    n_fixed = n_chains_fixed(inputs)
    path_fixed = create_path(inputs.target, inputs)
    initial_schedule_fixed = equally_spaced_schedule(n_fixed)
    fixed_leg = NonReversiblePT(path_fixed, initial_schedule_fixed, nothing)
    path_var = create_path(inputs.target, inputs) # start with the fixed reference
    n_var = n_chains_var(inputs)
    initial_schedule_var = equally_spaced_schedule(n_var)
    variational_leg = NonReversiblePT(path_var, initial_schedule_var, nothing)
    swap_graphs = variational_deo(n_fixed, n_var)
    log_potentials = concatenate_log_potentials(fixed_leg, variational_leg)
    indexer = create_replica_indexer(n_fixed, n_var)
    return StabilizedPT(fixed_leg, variational_leg, swap_graphs, log_potentials, indexer)
end

function adapt_tempering(tempering::StabilizedPT, reduced_recorders, iterators, variational, state)
    indexer = tempering.indexer
    variational_leg = adapt_tempering(
        tempering.variational_leg, reduced_recorders, iterators, 
        variational, state, variational_leg_indices(indexer)[1:(end-1)])
    fixed_leg = adapt_tempering(
        tempering.fixed_leg, reduced_recorders, iterators, 
        nothing, state, fixed_leg_indices(indexer)[2:end]) # we rely here on fixed_leg_indices giving the entries in decreasing order 
    log_potentials = concatenate_log_potentials(fixed_leg, variational_leg)
    return StabilizedPT(fixed_leg, variational_leg, tempering.swap_graphs, log_potentials, tempering.indexer)
end

function concatenate_log_potentials(fixed_leg::NonReversiblePT, variational_leg::NonReversiblePT)
    return vcat(variational_leg.log_potentials, reverse(fixed_leg.log_potentials))
end

tempering_recorder_builders(vpt::StabilizedPT) = tempering_recorder_builders(vpt.variational_leg)

create_pair_swapper(tempering::StabilizedPT, target) = tempering.log_potentials

function find_log_potential(replica, tempering::StabilizedPT, shared)
    tup = tempering.indexer.i2t[replica.chain]
    if tup.leg == :fixed 
        return tempering.fixed_leg.log_potentials[tup.chain]
    elseif tup.leg == :variational 
        return tempering.variational_leg.log_potentials[tup.chain]
    end
end

"""
$SIGNATURES
Create an `Indexer` for stabilized variational PT. 
Given a chain number, return a tuple indicating the relative chain number 
within a leg of PT and the leg in which it is located. 
Given a tuple, return the global chain number.
"""
function create_replica_indexer(n_chains_fixed::Int, n_chains_var::Int)
    n = n_chains_fixed + n_chains_var
    i2t = Vector{NamedTuple{(:chain, :leg), Tuple{Int64, Symbol}}}(undef, n)
    for i in 1:n
        # Note: 2023/07/20: changed order to have variational first (as depicted below)
        #                   to simplify log(Z) code for 2-legged

        # <--- variational ---->    <----- fixed ------>
        # reference ----- target -- target ---- reference 
        #     1     -----   N    -- N + 1  ----    2N
        if i ≤ n_chains_var 
            i2t[i] = (chain = i, leg = :variational)
        else 
            i2t[i] = (chain = n_chains_fixed - (i - n_chains_var) + 1, leg = :fixed)
        end
    end
    return Indexer(i2t)
end

# global indices, sorted from target to ref
fixed_leg_indices(indexer) = 
    reverse(findall(x->x[2] == :fixed, indexer.i2t))

# global indices, sorted from ref (1) to target (n_chains_var) 
variational_leg_indices(indexer) = 
    findall(x->x[2] == :variational, indexer.i2t)

global_barrier(tempering::StabilizedPT) = tempering.fixed_leg.communication_barriers.globalbarrier

global_barrier_variational(tempering::StabilizedPT) = tempering.variational_leg.communication_barriers.globalbarrier

global_barrier_variational(tempering) = error()