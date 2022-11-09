using Pigeons
using Documenter

DocMeta.setdocmeta!(Pigeons, :DocTestSetup, :(using Pigeons); recursive=true)

makedocs(;
    modules=[Pigeons],
    authors="Paul Tiede <ptiede91@gmail.com> and contributors",
    repo="https://github.com/Julia-Tempering/Pigeons.jl/blob/{commit}{path}#{line}",
    sitename="Pigeons.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://ptiede.github.io/Pigeons.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/ptiede/Pigeons.jl",
    devbranch="main",
)
