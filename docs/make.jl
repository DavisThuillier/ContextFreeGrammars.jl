using ContextFreeGrammars
using Documenter

DocMeta.setdocmeta!(ContextFreeGrammars, :DocTestSetup, :(using ContextFreeGrammars); recursive=true)

makedocs(;
    modules=[ContextFreeGrammars],
    authors="DavisThuillier <dsthuillier@gmail.com> and contributors",
    sitename="ContextFreeGrammars.jl",
    format=Documenter.HTML(;
        canonical="https://DavisThuillier.github.io/ContextFreeGrammars.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/DavisThuillier/ContextFreeGrammars.jl",
    devbranch="main",
)
