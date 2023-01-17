abstract type StreamTarget end

initialization(target::StreamTarget, rng::SplittableRandom, _::Int64) = 
    @abstract 

struct BlangTarget <: StreamTarget
    command::Cmd
end

function initialization(target::BlangTarget, rng::SplittableRandom, _::Int64)
    result = ExpectProc(
        `$(target.command) 
            --experimentConfigs.resultsHTMLPage false
            --experimentConfigs.saveStandardStreams false
            --engine blang.engines.internals.factories.Pigeons 
            --engine.random $(java_seed(rng))`,
        Inf # no timeout
    )
    finalizer(result) do procedure
        kill(procedure)
    end
    return result
end

# hack to convert to Long, fixme
function java_seed(rng::SplittableRandom) 
    result = "$(rand(rng, UInt64))"
    return result[1:(length(result) - 1)]
end

# Internals

struct StreamPath end 

@concrete struct SteamPotential 
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

sample_iid!(log_potential::SteamPotential, replica) = 
    call_sampler!(log_potential, replica.state)

create_path(target::StreamTarget, ::Inputs) = StreamPath()

interpolate(path::StreamPath, beta) = SteamPotential(beta)

(log_potential::SteamPotential)(worker::ExpectProc) = 
    invoke_worker(
        worker, 
        "log_potential($(log_potential.beta))", 
        Float64
    )

call_sampler!(log_potential::SteamPotential, worker::ExpectProc) = 
    invoke_worker(
        worker, 
        "call_sampler!($(log_potential.beta))"
    )

function invoke_worker(worker::ExpectProc, request::AbstractString, return_type::Type = Nothing)
    println(worker, request)
    expect!(worker, "response(")
    response_str = expect!(worker, ")")
    return return_type == Nothing ? nothing : parse(return_type, response_str)
end
