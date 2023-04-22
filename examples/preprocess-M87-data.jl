#=
For some reason, the Conda/PyCall stuff does not work on 
Sockeye, so doing it locally and serializing it.
=#

using Pkg
Pkg.activate(".")

using Comrade
using Serialization

obs = load_ehtim_uvfits("data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits")
obs = scan_average(obs.flag_uvdist(uv_min=0.1e9))
dlcamp = extract_lcamp(obs)
dcphase = extract_cphase(obs)

serialize("data/dlcamp.jl", dlcamp)
serialize("data/dcphase.jl", dcphase)