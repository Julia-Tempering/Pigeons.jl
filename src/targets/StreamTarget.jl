"""
A [`target`](@ref) based on running worker processes, one for each replica,
each communicating with Pigeons 
using [standard streams](https://en.wikipedia.org/wiki/Standard_streams). 
These worker processes can be implemented in an arbitrary programming language. 

[`StreamTarget`](@ref) implements [`log_potential`](@ref) and [`explorer`](@ref) 
by invoking worker processes via standard stream communication.
The standard stream is less efficient than alternatives such as 
protobuff, but it has the advantage of being supported by nearly all 
programming languages in existence. 
Also in many practical cases, since the worker 
process is invoked only three times per chain per iteration, it is
unlikely to be the bottleneck (overhead is in the order of 0.1ms).  

The worker process should be able to reply to commands of the following forms
(one command per line):

- `log_potential(0.6)` in the worker's `stdin` to which it should return a response of the form 
    `response(-124.23)` in its `stdout`, providing in this example the joint log density at `beta = 0.6`;
- `call_sampler!(0.4)` signaling that one round of local exploration should be performed 
    at `beta = 0.4`, after which the worker should signal it is done with `response()`.
"""
abstract type StreamTarget end

"""
$SIGNATURES 

Dispose of the child processes associated with the pt's 
[`StreamState`](@ref)'s
"""
function kill_child_processes(pt)
    for replica in locals(pt.replicas)
        Expect.kill(replica.state.worker_process)
    end
end

"""
$SIGNATURES

Return [`StreamState`](@ref) by following these steps:

1. create a `Cmd` that uses the provided `rng` to set the random seed properly, as well 
    as target-specific configurations provided by `target`.
2. Create [`StreamState`](@ref) from the `Cmd` created in step 1 and return it.
"""
initialization(target::StreamTarget, rng::AbstractRNG, replica_index::Int64) = @abstract 

""" 
States used in the replicas when a [`StreamTarget`](@ref) is used. 
"""
struct StreamState 
    worker_process::ExpectProc
    replica_index::Int
    """ 
    $SIGNATURES 

    Create a worker process based on the supplied `cmd`. 
    The work for the provided `replica_index` will be delegated to it.

    See [`StreamTarget`](@ref).
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

# Internals

struct StreamPath end 

#= 
Only store beta, since the worker process
will take care of path construction
=#
@auto struct StreamPotential 
    beta
end

default_explorer(target::StreamTarget) = target 

#= 
Delegate exploration to the worker process.
=#
function step!(explorer::StreamTarget, replica, shared)
    log_potential = find_log_potential(replica, shared.tempering, shared)
    call_sampler!(log_potential, replica.state)
end

#= 
Delegate iid sampling to the worker process.
Same call as explorer, rely on the worker to 
detect that the annealing parameter is zero.
=#
sample_iid!(log_potential::StreamPotential, replica, shared) = 
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

# convert a random UInt64 to positive Int64/Java-Long by dropping the sign bit
java_seed(rng::AbstractRNG) = (rand(split(rng), UInt64) >>> 1) % Int64

#=
Simple stdin/stdout text-based protocol. 
=#
function invoke_worker(
        state::StreamState, 
        request::AbstractString, 
        return_type::Type{T} = Nothing) where {T}
    println(state.worker_process, request)
    prefix = expect!(state.worker_process, "response(")
    if state.replica_index == 1 && 
            length(prefix) > 4 # otherwise running on windows spits a lot of empty lines
        # display output for replica 1 to show e.g. info messages
        print(prefix)
    end
    response_str = expect!(state.worker_process, ")")
    return T == Nothing ? nothing : parse(T, response_str)
end
