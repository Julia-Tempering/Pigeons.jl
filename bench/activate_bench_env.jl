# Use this to run benchmarks

# This script will add the parent project by path to the test project. 
# If we do not do this, we will end up benchmarking the 
# latest released version instead of the one checked out.

# We have to do this because ChildProcess/MPIProcesses depend on  
# a single toml file to know how to load Pigeons and other 
# dependencies. 

using Pkg
bench_dir = @__DIR__
@assert basename(bench_dir) == "bench"
Pkg.activate(bench_dir)

project_root_dir = dirname(bench_dir)
Pkg.develop(PackageSpec(path=project_root_dir))

# TODO: change this, it will be registered shortly
Pkg.add(url="https://github.com/Julia-Tempering/InferenceTargets", rev = "c449bb47694074742ae49ada2d4588361292429b")
using InferenceTargets
for collection in [:PigeonsExamples, :PosteriorDBTargets, :TuringPigeonsExamples]
    Pkg.add(InferenceTargets.registry[collection])
end
# we need to do this since we don't want to commit the Project.toml 
# as we are adding non-registered packages. Without this, it would 
# be easy to accidentally commit those non-registered to Project.toml.  
# In turn they cause crash in CI since we don't want Manifest.toml committed either. 
for pkg in ["BridgeStan", "MCMCChains", "Statistics"]
    Pkg.add(pkg)
end

# use single statement to avoid multiple precompile stages
using   BridgeStan,
        MCMCChains,
        PigeonsExamples,
        PosteriorDBTargets,
        Statistics,
        TuringPigeonsExamples
