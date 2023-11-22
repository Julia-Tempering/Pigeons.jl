""" 
States used in the replicas when a stream target is used. 
"""
struct StreamState 
    worker_process::ExpectProc
    replica_index::Int
    """ 
    $SIGNATURES 

    Create a worker process based on the supplied `cmd`. 
    The work for the provided `replica_index` will be delegated to it.
    """ 
    function StreamState(cmd::Cmd, replica_index::Int)
        worker_process = 
            ExpectProc(
                cmd,
                Inf # no timeout
            )
        return new(worker_process, replica_index)
    end
end

extract_sample(state::StreamState, log_potential) = extract_sample(state, log_potential, LogPotentialExtractor()) 
sample_names(state::StreamState, log_potential) = sample_names(state, log_potential, LogPotentialExtractor()) 