# ContextFreeGrammars.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://DavisThuillier.github.io/ContextFreeGrammars.jl/dev/)
[![Build Status](https://github.com/DavisThuillier/ContextFreeGrammars.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/DavisThuillier/ContextFreeGrammars.jl/actions/workflows/CI.yml?query=branch%3Amain)

ContextFreeGrammars.jl is a package for the Julia language that facilitates defining and parsing context-free grammars. Arbitrary grammars without epsilon productions can be defined, reduced to the minimal set of useful symbols, and converted to Chomsky normal form. 
Parsing is performed using the CYK algorithm. 

## Installation
Until this package is made available on the Julia General Registry, clone the package
```bash
$ git clone https://github.com/DavisThuillier/ContextFreeGrammars.jl.git
```
or add the package directly to your local Julia registry.
```julia
julia>]
pkg> add https://github.com/DavisThuillier/ContextFreeGrammars.jl
```
Nota Bene: cloning the full repository will also provide the examples given in `scripts/`.
