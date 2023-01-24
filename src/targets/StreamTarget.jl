abstract type StreamTarget end

initialization(target::StreamTarget, rng::SplittableRandom, replica_index::Int64) = @abstract 

#=
It would have been nicer and simpler to define the 
finalizer on the ExpectProc, but that does not work, 
i.e the finalizer does not get called. Instead we use 
a token to signal garbage collection
=#
mutable struct ProcessReaperToken # Note: needs to be mutable (see ?finalizer) 
    proc::Base.Process 
    function ProcessReaperToken(proc::Base.Process)
        result = new(proc)
        finalizer(_kill, result)
        return result
    end
end

function _kill(token::ProcessReaperToken) 
    # ccall from kill(process), we use the low level call at the 
    # recommendation of ?finalizer
    ccall(:uv_process_kill, Int32, (Ptr{Cvoid}, Int32), token.proc.handle, 15)
end

struct StreamState 
    worker_process::ExpectProc
    replica_index::Int
    token::ProcessReaperToken 
    function StreamState(cmd, replica_index)
        worker_process = 
            ExpectProc(
                cmd,
                Inf # no timeout
            )
        token = ProcessReaperToken(worker_process.proc)
        return new(worker_process, replica_index, token)
    end
end



# Internals

struct StreamPath end 

@concrete struct StreamPotential 
    beta
end

create_state_initializer(target::StreamTarget, ::Inputs) = target  
create_explorer(target::StreamTarget, ::Inputs) = target 
adapt_explorer(explorer::StreamTarget, _, _) = explorer 
explorer_recorder_builders(::StreamTarget) = [] 

function step!(explorer::StreamTarget, replica, shared)
    log_potential = find_log_potential(replica, shared)
    call_sampler!(log_potential, replica.state)
end

sample_iid!(log_potential::StreamPotential, replica) = 
    call_sampler!(log_potential, replica.state)

create_path(target::StreamTarget, ::Inputs) = StreamPath()

interpolate(path::StreamPath, beta) = StreamPotential(beta)

(log_potential::StreamPotential)(state::StreamState) = 
    invoke_worker(
            state, 
            "log_potential($(log_potential.beta))", 
            Float64
        )


call_sampler!(log_potential::StreamPotential, state::StreamState) = 
    invoke_worker(
        state, 
        "call_sampler!($(log_potential.beta))"
    )

# hack to convert UInt64 to Long; not in a loop so ok, 
# but fixme at some point
function java_seed(rng::SplittableRandom) 
    result = "$(rand(rng, UInt64))"
    return result[1:(length(result) - 1)]
end

function invoke_worker(
        state::StreamState, 
        request::AbstractString, 
        return_type::Type = Nothing)
    #=
    While this could be significanly optimized (e.g., using protobuf), 
    in many practical cases where one wants to use MPI, this is 
    unlikely to be the bottleneck. 

    For example, calling the log_potential evaluation on a basic blang 
    model takes in the order 0.1ms. This is only done twice per 
    communication step, since exploration is delegated to the worker. 
    In scenarios where it is attractive to use MPI, one exploration step 
    will typically be >0.1ms. 
    =#
    println(state.worker_process, request)
    prefix = expect!(state.worker_process, "response(")
    if state.replica_index == 1 && length(prefix) > 3
        print(prefix)
    end
    response_str = expect!(state.worker_process, ")")
    return return_type == Nothing ? nothing : parse(return_type, response_str)
end
