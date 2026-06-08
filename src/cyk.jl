tri(n) = (n * (n - 1)) ÷ 2
@inline tri_index(i, j) = tri(j) + i + 1

abstract type AbstractParseChart{N,T,E} end

nonterminals(chart::AbstractParseChart) = chart.nonterminals

"""
    input(chart::AbstractParseChart)

Return the input sequence (vector of terminals) that `chart` was built from.
"""
input(chart::AbstractParseChart) = chart.input

"""
    start_index(chart::AbstractParseChart)

Return the index of the grammar's start symbol within `nonterminals(chart)`. The start
symbol itself is `start(chart)`.
"""
start_index(chart::AbstractParseChart) = chart.start
start(chart::AbstractParseChart) = nonterminals(chart)[start_index(chart)]

"""
    CYKParseChart{N, T, E}

The dynamic-programming chart produced by [`cyk`](@ref). For each span `(i, j)` of the
input and each nonterminal `A`, it stores the inside value—the total semiring weight of
all derivations of `input[i+1:j]` from `A`—as an element of type `E`. Spans use
half-open, zero-based indexing, so the whole input is the span `(0, length(input))`.

Read inside values with [`inside`](@ref) and the overall value of the input with
[`val`](@ref). Access the chart's metadata with [`input`](@ref), `nonterminals`,
[`start_index`](@ref), and `start`.
"""
struct CYKParseChart{N, T, E} <: AbstractParseChart{N, T, E}
    vals::Matrix{E}
    nonterminals::Vector{N}
    input::Vector{T}
    start::Int # Index of start symbol in nonterminals
end

function CYKParseChart{N, T, E}(input::AbstractVector{T}, nonterminals::AbstractVector{N}, S::N) where {N, T, E}
    n = length(input)
    start = findfirst(isequal(S), nonterminals)
    return CYKParseChart(zeros(E, tri(n + 1), length(nonterminals)), nonterminals, input, start)
end

CYKParseChart{N, T, E}(input::AbstractVector{T}, nonterminals::Set{N}, S::N) where {N, T, E} = CYKParseChart(input, collect(nonterminals), S)

function Base.setindex!(c::CYKParseChart{N, T, E}, val::E, i::Int, j::Int, k::Int) where {N, T, E}
    c.vals[tri_index(i, j), k] = val
end
Base.getindex(c::CYKParseChart, i::Int, j::Int, k::Int) = c.vals[tri_index(i, j), k]

# Goodman, semiring parsing

"""
    cyk(input::AbstractVector, grammar::AbstractGrammar)
    cyk(input::String, grammar::AbstractGrammar; dlm = " ")

Run the CYK algorithm and return the filled [`CYKParseChart`](@ref) for `input` under
`grammar`. The grammar must be in Chomsky normal form (see
[`in_chomsky_normal_form`](@ref) and [`ChomskyNormalFormContextFreeGrammar`](@ref)),
otherwise an `ArgumentError` is thrown.

This is the semiring formulation of CYK (Goodman, *Semiring Parsing*): every chart cell
accumulates the inside value of its span in the grammar's semiring, so the same code
recognizes (Boolean), counts derivations ([`CountSemiring`](@ref)), or sums their
probability mass ([`ProbabilisticSemiring`](@ref)) depending on the production weights.

When `input` is a `String` it is split into tokens on the delimiter `dlm` before
parsing. Query the resulting chart with [`inside`](@ref) or [`val`](@ref).
"""
function cyk(input::AbstractVector{T}, grammar::AbstractGrammar{N,T,E}) where {N, T, E}
    in_chomsky_normal_form(grammar) || throw(ArgumentError(" grammar must be in ChomskyNormalForm"))
    n = length(input)

    V = collect(nonterminals(grammar)) # Make indexed vector of symbols
    Σ = collect(terminals(grammar)) # Make indexed vector of symbols

    terminal_productions = filter(is_terminal_production, productions(grammar))
    binary_productions   = filter(x -> !is_terminal_production(x), productions(grammar))

    terminal_idx_weights = map( 
        x -> (findfirst( isequal(lhs(x)), V), 
              findfirst( isequal(val(first(rhs(x)))), Σ),
              weight(x)
        ), 
        terminal_productions
    )

    binary_idx_weights = map( 
        x -> (findfirst( isequal(lhs(x)), V), 
              findfirst( isequal(val(first(rhs(x)))), V),
              findfirst( isequal(val(last(rhs(x)))), V),
              weight(x)
        ), 
        binary_productions
    )

    chart = CYKParseChart{N, T, E}(input, V, start(grammar)) # Look-up table for inside values

    for i ∈ 1:n
        for (A, a, w) ∈ terminal_idx_weights # A -> a
            if input[i] == Σ[a]
                chart[i-1, i, A] += w
            end
        end
    end

    for len ∈ 2:n # length, shortest to longest
        for i ∈ 0:(n-len) # start position
            j = i + len
            for k ∈ i+1:j-1 # split position
                for (A, B, C, w) ∈ binary_idx_weights
                    chart[i, j, A] += chart[i, k, B] * chart[k, j, C] * w
                end
            end
        end
    end
    
    return chart
end

function cyk(input::String, grammar::AbstractGrammar; dlm = " ")
    words = String.(split(input, dlm))
    return cyk(words, grammar)
end

function findfirstsub(sub::AbstractVector, seq::AbstractVector)
    n, m = length(seq), length(sub)
    m == 0 && return 1:0
    for i in 1:(n - m + 1)
        @views seq[i:i+m-1] == sub && return (i,i+m-1)
    end
    return nothing
end

"""
    inside(i::Int, j::Int, C, chart::AbstractParseChart)
    inside(i::Int, j::Int, k::Int, chart::CYKParseChart)
    inside(subsequence::AbstractVector, C, chart::AbstractParseChart)
    inside(substring::AbstractString, C, chart::AbstractParseChart; dlm = " ")
    inside(subsequence::AbstractVector, C, input::AbstractVector, grammar::AbstractGrammar)

Return the inside value for nonterminal `C` over a span of the input recorded in
`chart`—that is, the total semiring weight of all derivations of that span from `C`,
unwrapped with [`val`](@ref) to a plain value.

The span may be given directly as the half-open, zero-based bounds `(i, j)`, with the
nonterminal named either by its symbol `C` or by its column index `k`. Alternatively,
pass a `subsequence` (or whitespace/`dlm`-delimited `substring`) and the span is located
within `input(chart)` by its first occurrence, throwing an `ArgumentError` if it is not
present. The final form takes a raw `input` and `grammar`, parsing with [`cyk`](@ref)
before querying.
"""
inside(i::Int, j::Int, k::Int, chart::CYKParseChart{N, T, E}) where {N, T, E} = val(chart[i, j, k])

function inside(i::Int, j::Int, C::N, chart::AbstractParseChart{N, T, E}) where {N, T, E}
    k = findfirst(isequal(C), nonterminals(chart)) # Column index of symbol C
    return inside(i, j, k, chart)
end

function inside(subsequence::AbstractVector{T}, C::N, chart::AbstractParseChart{N, T, E}) where {N, T, E}
    span = findfirstsub(subsequence, input(chart))
    isnothing(span) && throw(ArgumentError("subsequence not found in input"))
    return inside(span[1] - 1, span[2], C, chart)
end

function inside(substring::AbstractString, C::N, chart::AbstractParseChart{N, T, E}; dlm = " ") where {N, T, E}
    words = String.(split(substring, dlm))
    return inside(words, C, chart)
end

function inside(subsequence::AbstractVector{T}, C::N, input::AbstractVector{T}, grammar::AbstractGrammar{N,T,E}) where {N,T,E}
    chart = cyk(input, grammar)
    return inside(subsequence, C, chart)
end

"""
    val(chart::AbstractParseChart)
    val(input::AbstractVector, grammar::AbstractGrammar)
    val(input::String, grammar::AbstractGrammar; dlm = " ")

Return the value of the whole input under the grammar: the inside value of the start
symbol over the entire span, unwrapped with [`val`](@ref). Its meaning depends on the
semiring—`true`/`false` for recognition with the [`BooleanSemiring`](@ref), a
derivation count with the [`CountSemiring`](@ref), or total probability mass with the
[`ProbabilisticSemiring`](@ref).

Given a filled [`CYKParseChart`](@ref) it reads the answer off the chart; given a raw
`input` (a vector of terminals, or a `dlm`-delimited `String`) and a `grammar`, it first
parses with [`cyk`](@ref).
"""
function val(chart::AbstractParseChart{N,T,E}) where {N, T, E}
    return inside(0, length(input(chart)), start_index(chart), chart)
end

function val(input::AbstractVector{T}, grammar::AbstractGrammar{N, T, E}) where {N, T, E}
    chart = cyk(input, grammar)
    return inside(0, length(input), start_index(chart), chart)
end

function val(input::String, grammar::AbstractGrammar{N, T, E}; dlm = " ") where {N, T, E}
    words = String.(split(input, dlm))
    chart = cyk(words, grammar)
    return inside(0, length(words), start_index(chart), chart)
end
