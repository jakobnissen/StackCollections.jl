using Documenter, StackCollections

DocMeta.setdocmeta!(StackCollections, :DocTestSetup, :(using StackCollections); recursive=true)

makedocs(;
    modules=[StackCollections],
    format=Documenter.HTML(),

    pages = [
        "Home" => "index.md",
        "Reference" => "reference.md",
    ],
    repo="https://github.com/jakobnissen/StackCollections.jl/blob/{commit}{path}#L{line}",
    sitename="StackCollections.jl",
    authors="Jakob Nybo Nissen",
    assets=String[],
)

deploydocs(;
    repo="github.com/jakobnissen/StackCollections.jl.git",
)
