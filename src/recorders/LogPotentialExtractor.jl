"""
Signal that only the log potential should be recorded into 
[`traces`](@ref). See `pt.inputs.extractor`.
"""
struct LogPotentialExtractor end 

extract_sample(state, log_potential, extractor::LogPotentialExtractor) = [log_potential(state)]

sample_names(state, log_potential, extractor::LogPotentialExtractor) = [:log_density]