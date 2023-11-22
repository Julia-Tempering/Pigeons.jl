module PigeonsMCMCChainsExt

using Pigeons
if isdefined(Base, :get_extension)
    using DocStringExtensions
    using MCMCChains
else
    using ..DocStringExtensions
    using ..MCMCChains
end

MCMCChains.Chains(pt::PT) = Chains(sample_array(pt), sample_names(pt), Dict(:internals => [:log_density]))

end
