struct BlangTarget <: StreamTarget
    command::Cmd
end

initialization(target::BlangTarget, rng::SplittableRandom, replica_index::Int64) = 
    StreamState(
        `$(target.command) 
            --experimentConfigs.resultsHTMLPage false
            --experimentConfigs.saveStandardStreams false
            --engine blang.engines.internals.factories.Pigeons 
            --engine.random $(java_seed(rng))`,
        replica_index)