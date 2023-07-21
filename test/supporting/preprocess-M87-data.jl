#=
For some reason, the Conda/PyCall stuff does not work on 
Sockeye, so doing it locally and serializing it.
=#

using Pigeons
const example_dir = abspath(dirname(dirname(pathof(Pigeons))) * "/examples")

using Comrade
using Serialization

### For black-hole-imaging*

obs = load_ehtim_uvfits("$example_dir/data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits")
obs = scan_average(obs.flag_uvdist(uv_min=0.1e9))
dlcamp = extract_lcamp(obs)
dcphase = extract_cphase(obs)

serialize("$example_dir/data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.dlcamp.jl", dlcamp)
serialize("$example_dir/data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.dcphase.jl", dcphase)


### For hybrid 

obs = load_ehtim_uvfits("$example_dir/data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits")
obs = scan_average(obs).add_fractional_noise(0.02)
dlcamp = extract_lcamp(obs; snrcut=4)
dcphase = extract_cphase(obs; snrcut=3)

serialize("$example_dir/data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.hybrid.dlcamp.jl", dlcamp)
serialize("$example_dir/data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.hybrid.dcphase.jl", dcphase)


### For closures

obs = load_ehtim_uvfits("$example_dir/data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits")
obs = scan_average(obs).add_fractional_noise(0.02)
dlcamp = extract_lcamp(obs; snrcut=3.0)
dcphase = extract_cphase(obs; snrcut=3.0)

serialize("$example_dir/data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.closures.dlcamp.jl", dlcamp)
serialize("$example_dir/data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.closures.dcphase.jl", dcphase)

