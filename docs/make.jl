# make sure we are using the version contained 
# in whatever state the parent directory is; 
# this is the intended behaviour both for CI and 
# local development
using Pkg
script_dir = @__DIR__
Pkg.activate(script_dir)
parent_dir = dirname(script_dir)
Pkg.develop(PackageSpec(path=parent_dir))


using Pigeons
using Documenter
using DocStringExtensions 
using Plots

# based on: https://github.com/JuliaPlots/PlotlyJS.jl/blob/master/docs/make.jl
using PlotlyJS
using PlotlyBase
PlotlyJS.set_default_renderer(PlotlyJS.DOCS)

DocMeta.setdocmeta!(Pigeons, :DocTestSetup, :(using Pigeons); recursive=true)

makedocs(;
    modules=[Pigeons],
    authors="Miguel Biron-Lattes <miguel.biron@stat.ubc.ca>, Alexandre Bouchard-Côté <alexandre.bouchard@gmail.com>, Trevor Campbell <trevor@stat.ubc.ca>, Nikola Surjanovic <nikola.surjanovic@stat.ubc.ca>, Saifuddin Syed <saifuddin.syed@stats.ox.ac.uk>, Paul Tiede <ptiede91@gmail.com>",
    repo="https://github.com/Julia-Tempering/Pigeons.jl/blob/{commit}{path}#{line}",
    sitename="Pigeons.jl",
    strict=true,
    format=Documenter.HTML(;
        prettyurls=true, # always on, avoids confusion when building locally. If needed, serve the "build" folder locally with LiveServer. #get(ENV, "CI", "false") == "true",
        canonical="https://Julia-Tempering.github.io/Pigeons.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Basic usage (local)" => "index.md",
        "Why PT?" => "unidentifiable-example.md",
        "Parallelization" => "parallel.md", 
        "Distributed usage (MPI)" => "mpi.md",
        "Variational PT" => "variational.md", 
        "Supported inputs" => [
            "Inputs overview" => "input-overview.md",
            "Turing.jl model" => "input-turing.md", 
            "Black-box function" => "input-julia.md",
            "Stan model" => "input-stan.md", 
            "Non-julian MCMC" => "input-nonjulian.md", 
            "Custom MCMC" => "input-explorers.md"
        ],
        "Outputs" => [
            "Outputs overview" => "output-overview.md",
            "Quick reports" => "output-reports.md", 
            "Plots" => "output-plotting.md", 
            "log(Z)" => "output-normalization.md", 
            "Numerical" => "output-numerical.md", 
            "Online stats" => "output-online.md", 
            "Off-memory" => "output-off-memory.md", 
            "PT diagnostics" => "output-pt.md", 
            "Custom types" => "output-custom-types.md",
            "MPI output" => "output-mpi-postprocessing.md"
        ],
        "Checkpoints" => "checkpoints.md",
        "Correctness checks" => "correctness.md",
        "More on PT" => "pt.md", 
        "More on distributed PT" => "distributed.md",
        "Interfaces" => Pigeons.informal_doc(@__DIR__, Pigeons),
        "Reference" => "reference.md",
    ],
)

rm(joinpath(script_dir, "build", "results"), recursive=true) # delete `results` folder before deploying

deploydocs(;
    repo="github.com/Julia-Tempering/Pigeons.jl",
    devbranch="main",
)
