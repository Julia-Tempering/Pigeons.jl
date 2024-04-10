#=
TASK: recreate Fig. 6 in Ballnus et al. (2017)
=#

include("activate_test_env.jl")

using CSV, DataFrames, PairPlots, CairoMakie

# load data
dta_path = joinpath(dirname(@__DIR__), "examples", "data", "Ballnus_et_al_2017_M1a.csv")
dta = CSV.read(dta_path, DataFrame; header=0)
N = nrow(dta)
ts = dta[!,1]
ys = dta[!,2]

# create model target and reference
model_file = joinpath(dirname(@__DIR__), "examples", "stan", "mRNA.stan")
mRNA_target = StanLogPotential(model_file, Pigeons.json(; N, ts, ys))
prior_ref = DistributionLogPotential(product_distribution(
    Uniform(-2,1), Uniform(-5,5), Uniform(-5,5), Uniform(-5,5), Uniform(-2,2)
))

# run
pt = pigeons(
    target = mRNA_target, 
    reference = prior_ref, 
    record = [traces; round_trip; record_default()],
    multithreaded = false,
    n_chains = 15,
    n_rounds = 4,
    # checkpoint = true,
    # on = ChildProcess(
    #     n_local_mpi_processes = 4,
    #     n_threads = 1,
    #     dependencies = [BridgeStan]
    # )
)
samples = Chains(pt)
fig = pairplot(samples[:,1:5,:])
save("myfigure.png", fig)