using Pigeons
using Documenter
using DocStringExtensions 

DocMeta.setdocmeta!(Pigeons, :DocTestSetup, :(using Pigeons); recursive=true)

makedocs(;
    modules=[Pigeons],
    authors="Miguel Biron-Lattes <miguel.biron@stat.ubc.ca>, Alexandre Bouchard-Côté <alexandre.bouchard@gmail.com>, Trevor Campbell <trevor@stat.ubc.ca>, Nikola Surjanovic <nikola.surjanovic@stat.ubc.ca>, Saifuddin Syed <saifuddin.syed@stats.ox.ac.uk>, Paul Tiede <ptiede91@gmail.com>",
    repo="https://github.com/Julia-Tempering/Pigeons.jl/blob/{commit}{path}#{line}",
    sitename="Pigeons.jl",
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
