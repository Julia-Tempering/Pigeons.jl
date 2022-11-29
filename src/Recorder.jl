"""
Statistics in the process of being collected. In particular, in an MPI environment 
    they have not been reduced yet. Use reduced_stats(..) to do the reduction.
"""
struct Recorder{C, S} 
    communicator::C # current implementations: Nothing or Comm
    stats::S        # S will typically be a NamedTuple carrying all the statistics we may need to MPI-reduce
end

# TODO: write samples to disk as well?

Recorder(replicas) = Recorder(communicator(replicas), empty_stat())
empty_stats() = (;
        :swap_acceptance_pr = GroupBy(Int, Mean())
    )

function fit_if_defined!(stats_tuple, key, value)
    if has_key(stats_tuple, key)
        fit!(stats_tuple[key], value)
    end
end

function record_swap_stats!(recorder::Recorder, chain1::Int, stat1::SwapStat, chain2::Int, stat2::SwapStat)
    acceptance_pr = swap_acceptance_probability(stat1, stat2)
    index = min(chain1, chain2)
    fit_if_defined!(recorder.stats, :swap_acceptance_pr, (index, acceptance_pr))
    # TODO accumulate stepping-stone statistics
end

# Called between each iteration, where iteration is defined as (swaps!(...) followed by explore!(...))
function record_iteration_stats!(recorder::Recorder, iteration::Int, replicas)
    TODO
end

function record_proposal_stats!(recorder::Recorder, TODO)
    TODO
end

reduced_stats(recorder) = reduced_stats(recorder.communicator, recorder.stats)
reduced_stats(comm::Nothing, stats) = stats
reduced_stats(comm::Comm, stats) = MPI.Allreduce(stats, merge_stat_tuple, comm)

function merge_stat_tuple(stat1, stat2)
    shared_keys = keys(stat1)
    @assert shared_keys == keys(stat2)
    values1 = values(stat1)
    values2 = values(stat2)
    merged_values = [merge(value1[i], value1[i]) for i in eachindex(value1)]
    return (; zip(shared_keys, merged_values)...)
end

