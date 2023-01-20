abstract type StreamTarget end

initialization(target::StreamTarget, rng::SplittableRandom, _::Int64) = 
    @abstract 


mutable struct StreamState{P, R} # mutable so that it can be finalized (see ?finalized)
    process::P
    replica_index::R
    function StreamState(process::P, replica_index::R) where {P, R}
        result = new{P, R}(process, replica_index)
        finalizer(result) do state
            kill(state.process)
        end 
        return result
    end
end

struct BlangTarget <: StreamTarget
    command::Cmd
end



initialization(target::BlangTarget, rng::SplittableRandom, replica_index::Int64) =
    result = ExpectProc(
        `$(target.command) 
            --experimentConfigs.resultsHTMLPage false
            --experimentConfigs.saveStandardStreams false
            --engine blang.engines.internals.factories.Pigeons 
            --engine.random $(java_seed(rng))`,
        Inf # no timeout
    )
    # TODO: find a way to kill the child process after GC; 
    # the code below does not work for some reason. 
    # finalizer(result) do procedure
    #     kill(procedure)
    # end



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

(log_potential::StreamPotential)(worker::ExpectProc) = 
    invoke_worker(
            worker, 
            "log_potential($(log_potential.beta))", 
            Float64
        )


call_sampler!(log_potential::StreamPotential, worker::ExpectProc) = 
    invoke_worker(
        worker, 
        "call_sampler!($(log_potential.beta))"
    )

# hack to convert UInt64 to Long; not in a loop so ok, 
# but fixme at some point
function java_seed(rng::SplittableRandom) 
    result = "$(rand(rng, UInt64))"
    return result[1:(length(result) - 1)]
end

function invoke_worker(
        worker::ExpectProc, 
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
    println(worker, request)
    expect!(worker, "response(")
    response_str = expect!(worker, ")")
    return return_type == Nothing ? nothing : parse(return_type, response_str)
end
