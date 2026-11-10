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
        "Manual" => [
            "Glossary" => "glossary.md",
            "Passing a table" => "tables.md",
            "Stepping and watching a run" => "running.md",
            "Missing responses" => "missing.md",
            "How precise is a p-value?" => "precision.md",
            "Threads and reproducibility" => "reproducibility.md",
            "Known limitation: floating-point ties" => "ties.md",
            "How it is checked" => "verification.md",
        ],
        "API reference" => "api.md",
    ],
)

deploydocs(;
    repo="github.com/jerome-white/RandomizedTukeyHSD.jl",
    devbranch="master",
    push_preview=true,
)
