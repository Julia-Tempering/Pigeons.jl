"""
$SIGNATURES 

Run (a generalization of) Parallel Tempering. 

This will call several rounds of [`run_one_round!()`](@ref), 
performing adaptation between each round via [`adapt()`](@ref).

This will also call [`report!()`](@ref), [`write_checkpoint()`](@ref), 
and [`run_checks()`](@ref) between rounds. 
"""
function pigeons(pt::PT) 
    only_one_process(pt) do
        preflight_checks(pt.inputs)
    end
    prev_reports = nothing
    while next_round!(pt) # NB: while-loop instead of for-loop to support resuming from checkpoint
        reduced_recorders = run_one_round!(pt)
        pt = adapt(pt, reduced_recorders) 
        # NB: the local variable pt here is not type-stable b/c adapt(..), e.g. will 
        # change type of tempering.communication_barrier from nothing to a value 
        # but since this loop is ran only a logarithmic # of times no performance hit
        prev_reports = report!(pt, prev_reports)
        write_checkpoint(pt) 
        run_checks(pt)
    end
    return pt 
end

"""
$SIGNATURES 

From a [`PT`](@ref) object, run one round of 
a generalized version of Algorithm 1 in 
[Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).

Alternates between [`communicate!()`](@ref), 
which consists of any pairwise communicating 
moves and [`explore!()`], which consists of  
moves independent to each chain. 

Concrete specification of how to communicate and 
explore are specified by the field of type [`Shared`](@ref) 
contained in the provided [`PT`](@ref). 
"""
function run_one_round!(pt)
    explorer = pt.shared.explorer
    multithreaded = multithreaded_flag(pt.inputs.multithreaded)
    timed = @timed while next_scan!(pt)
        explore!(pt, explorer, multithreaded)
        communicate!(pt)
    end
    record_timed_if_requested!(pt, :round, timed)
    return reduce_recorders!(pt, pt.replicas)
end

"""
$SIGNATURES 

Use [`create_pair_swapper()`](@ref) and 
[`create_swap_graph`](@ref) to construct the 
inputs needed for [`swap!`](@ref).
"""
function communicate!(pt)
    tempering = pt.shared.tempering
    swapper = create_pair_swapper(tempering, pt.inputs.target)
    graph = create_swap_graph(tempering.swap_graphs, pt.shared)
    swap!(swapper, pt.replicas, graph)
end

"""
$SIGNATURES 

Call [`sample_iid!`](@ref) or [`step!()`](@ref) on 
each chain (depending if it is a reference or not 
respectively). 

Uses `@threads` to parallelize across threads. 
This is safe by the contract described in 
[`sample_iid!()`](@ref) and [`step!()`](@ref).
"""
explore!(pt, explorer, multithreaded_flag::Val{true}) =
    @threads for replica in locals(pt.replicas)
        explore!(pt, replica, explorer)
    end

"""
$SIGNATURES

The `@threads` macro brings a large overhead even 
when `Threads.nthreads == 1`, so a separate method 
is used for the single thread mode.
"""
explore!(pt, explorer, multithreaded::Val{false}) =
    for replica in locals(pt.replicas)
        explore!(pt, replica, explorer)
    end

multithreaded_flag(flag) = Val(flag && Threads.nthreads() > 1)

function explore!(pt, replica, explorer)
    log_potential = find_log_potential(replica, pt.shared.tempering, pt.shared)
    before = eval_if_ac_requested(log_potential, replica)
    if is_reference(pt.shared.tempering.swap_graphs, replica.chain)
        sample_iid!(log_potential, replica, pt.shared)
    else
        step!(explorer, replica, pt.shared)
    end
    process_ac!(log_potential, replica, before)
    if is_target(pt.shared.tempering.swap_graphs, replica.chain)
        @record_if_requested!(replica.recorders, :online, extract_sample(replica.state, log_potential))
        @record_if_requested!(replica.recorders, :_transformed_online, replica.state)
        @record_if_requested!(
            replica.recorders, 
            :traces, 
            (; 
                chain = replica.chain, 
                scan = pt.shared.iterators.scan, 
                contents = 
                    if pt.inputs.trace_type == :samples
                        extract_sample(replica.state, log_potential)
                    elseif pt.inputs.trace_type == :log_potential 
                        log_potential(replica.state) 
                    else
                        error()
                    end
            )
        )
        @record_if_requested!(
            replica.recorders, 
            :disk, 
            (; pt, replica)
        )
    end 
end

eval_if_ac_requested(log_potential, replica) = 
    haskey(replica.recorders, :energy_ac1) ?
        log_potential(replica.state) :
        0.0 

process_ac!(log_potential, replica, before) =
    if haskey(replica.recorders, :energy_ac1)
        after = log_potential(replica.state)
        record!(replica.recorders[:energy_ac1], (replica.chain, SVector(before, after)))
    end


"""
$SIGNATURES 

Call [`adapt_tempering()`](@ref) followed by 
[`adapt_explorer`](@ref).
"""
function adapt(pt, reduced_recorders)
    updated_tempering = adapt_tempering(pt.shared.tempering, reduced_recorders, pt.shared.iterators, pt.inputs.variational, locals(pt.replicas)[1].state)
    updated_explorer = adapt_explorer(pt.shared.explorer, reduced_recorders, pt, updated_tempering)
    updated_shared = Shared(
        pt.shared.iterators, 
        updated_tempering, 
        updated_explorer, 
        pt.shared.reports)
    updated_replicas = pt.replicas # TODO: adapt too? e.g. assign to closest from previous, leveraging checkpoints?
    return PT(pt.inputs, updated_replicas, updated_shared, pt.exec_folder, reduced_recorders)
end