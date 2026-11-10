using Documenter
using RandomizedTukeyHSD

DocMeta.setdocmeta!(RandomizedTukeyHSD, :DocTestSetup,
                    :(using Random, RandomizedTukeyHSD); recursive=true)

makedocs(;
    sitename="RandomizedTukeyHSD.jl",
    modules=[RandomizedTukeyHSD],
    authors="Jerome White",
    checkdocs=:exports,
    pages=[
        "Home" => "index.md",
        "API reference" => "api.md",
    ],
)

deploydocs(;
    repo="github.com/jerome-white/RandomizedTukeyHSD.jl",
    devbranch="master",
    push_preview=true,
)
