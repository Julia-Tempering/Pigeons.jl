"""
Signal that only the log potential should be recorded into 
[`traces`](@ref). See `extractor` in [`Inputs`](@ref).
"""
struct LogPotentialExtractor end 

extract_sample(state, log_potential, extractor::LogPotentialExtractor) = [log_potential(state)]

variable_names(state, log_potential, extractor::LogPotentialExtractor) = [:log_density]