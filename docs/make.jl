using Pidgeons
using Documenter

DocMeta.setdocmeta!(Pidgeons, :DocTestSetup, :(using Pidgeons); recursive=true)

makedocs(;
    modules=[Pidgeons],
    authors="Paul Tiede <ptiede91@gmail.com> and contributors",
    repo="https://github.com/ptiede/Pidgeons.jl/blob/{commit}{path}#{line}",
    sitename="Pidgeons.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://ptiede.github.io/Pidgeons.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/ptiede/Pidgeons.jl",
    devbranch="main",
)
