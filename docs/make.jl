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
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://Julia-Tempering.github.io/Pigeons.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Guide" => "index.md", 
        "Parallel Tempering (PT)" => "pt.md", 
        "Distributed PT" => "distributed.md",
        "Interfaces" => Pigeons.informal_doc(@__DIR__, Pigeons),
        "Reference" => "reference.md",
    ],
)

deploydocs(;
    repo="github.com/Julia-Tempering/Pigeons.jl",
    devbranch="main",
)
