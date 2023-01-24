""" 
A [`StreamTarget`](@ref) delegating exploration to 
[Blang worker processes](https://www.stat.ubc.ca/~bouchard/blang/).

For an example, see `test/single_cell_example.jl`.

Limitation: this should be called on a pre-compiled blang model, 
i.e. via `java package.MyBlangModel ...`, rather than via 
`blang ...` since the latter could cause several MPI processes to 
simultaneously attempt to compile in the same directory. 
Here is a workaround if your workflow is based on the `blang ...`
invocation. First, run a short run locally using e.g. 
`blang --engine.nScans 10 ...`. This will compile the blang code 
in the hidden folder `.blang-compilation/build/blang/`
"""
struct BlangTarget <: StreamTarget
    command::Cmd
end

# TODO: move nowellpack here; add blangdemo

initialization(target::BlangTarget, rng::SplittableRandom, replica_index::Int64) = 
    StreamState(
        `$(target.command) 
            --experimentConfigs.resultsHTMLPage false
            --experimentConfigs.saveStandardStreams false
            --engine blang.engines.internals.factories.Pigeons 
            --engine.random $(java_seed(rng))`,
        replica_index)