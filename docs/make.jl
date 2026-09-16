using Documenter, StackCollections

# This code is executed in the environment in which doctests in the package's
# docstrings run. Use it to define global variables that docstrings can refer
# to.
meta = quote
    nothing
end

DocMeta.setdocmeta!(StackCollections, :DocTestSetup, meta; recursive = true)

makedocs(
    modules = [BioJuliaTemplate],
    repo = Documenter.Remotes.GitHub("jakobnissen", "StackCollections.jl"),
    sitename = "StackCollections.jl",
    doctest = true,
    # These two pages are recommended, you can add more as you wish
    pages = [
        "Home" => "index.md",
        "USet" => "uset.md",
        "UVec" => "uvec.md",
        "Reference" => "reference.md",
    ],
    authors = ["Jakob Nybo Andersen"],
    checkdocs = :public,
)

deploydocs(;
    repo = "github.com/BioJulia/BioJuliaTemplate.jl.git",
    push_preview = true,
    deps = nothing,
    make = nothing,
)
