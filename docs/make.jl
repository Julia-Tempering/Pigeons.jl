using DynamicPPL
using BridgeStan
using Pigeons
using Documenter
using Documenter.Remotes: GitHub
using DocStringExtensions
using Plots
using InferenceReport

# based on: https://github.com/JuliaPlots/PlotlyJS.jl/blob/master/docs/make.jl
using PlotlyJS
using PlotlyBase
PlotlyJS.set_default_renderer(PlotlyJS.DOCS)

DocMeta.setdocmeta!(Pigeons, :DocTestSetup, :(using Pigeons); recursive=true)

InferenceReport.headless() do
    makedocs(;
        modules=[Pigeons],
        authors="Miguel Biron-Lattes <miguel.biron@stat.ubc.ca>, Alexandre Bouchard-Côté <alexandre.bouchard@gmail.com>, Trevor Campbell <trevor@stat.ubc.ca>, Nikola Surjanovic <nikola.surjanovic@stat.ubc.ca>, Saifuddin Syed <saifuddin.syed@stats.ox.ac.uk>, Paul Tiede <ptiede91@gmail.com>",
        repo=GitHub("Julia-Tempering/Pigeons.jl"),
        sitename="Pigeons.jl",
        # strict=true, # deprecated in v1.0.0. now it is the default. see https://github.com/JuliaDocs/Documenter.jl/blob/77f0bdd7c742fc7d7ed91c6b0ab6582f14e33e81/CHANGELOG.md?plain=1#L51
        format=Documenter.HTML(;
            prettyurls=true, # always on, avoids confusion when building locally. If needed, serve the "build" folder locally with LiveServer. #get(ENV, "CI", "false") == "true",
            canonical="https://Julia-Tempering.github.io/Pigeons.jl",
            edit_link="main",
            assets=String[],
            size_threshold = nothing # overrides default size limit for a single html file
        ),
        pages=[
            "Basic usage (local)" => "index.md",
            "Why parallel tempering (PT)?" => "unidentifiable-example.md",
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
                "Automated reports" => "output-inferencereport.md",
                "Standard output" => "output-reports.md",
                "Traces" => "output-traces.md",
                "Plots" => "output-plotting.md",
                "log(Z)" => "output-normalization.md",
                "Numerical" => "output-numerical.md",
                "Online stats" => "output-online.md",
                "Off-memory" => "output-off-memory.md",
                "PT diagnostics" => "output-pt.md",
                "Custom types" => "output-custom-types.md",
                "Extended output" => "output-extended.md",
                "MPI output" => "output-mpi-postprocessing.md"
            ],
            "Checkpoints" => "checkpoints.md",
            "Correctness checks" => "correctness.md",
            "More on PT" => "pt.md",
            "More on distributed PT" => "distributed.md",
            "Interfaces" => Pigeons.informal_doc(@__DIR__, Pigeons),
            "Reference" => "reference.md",
            "For developers" => "developers.md",
            "Openings" => "openings.md",
            "About Us" => "about-us.md"
        ],
    )
end

try
    rm(joinpath(script_dir, "build", "results"), recursive=true) # delete `results` folder before deploying
catch 
end

deploydocs(;
    repo="github.com/Julia-Tempering/Pigeons.jl",
    devbranch="main",
)
