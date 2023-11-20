module PigeonsMCMCChainsExt

using Pigeons
if isdefined(Base, :get_extension)
    using DocStringExtensions
    using MCMCChains
    import MCMCChains.Chains
else
    using ..DocStringExtensions
    using ..MCMCChains
    import MCMCChains.Chains
end

MCMCChains.Chains(pt::PT) = Chains(sample_array(pt), variable_names(pt), Dict(:internals => [:log_density]))

end
