###
### Grammar Symbols
###

abstract type AbstractGrammarSymbol end

# Internal tagging scheme
struct TerminalSymbol{T} <: AbstractGrammarSymbol; val::T; end
struct NonterminalSymbol{N} <: AbstractGrammarSymbol; val::N; end

function tag_symbol(sym, V::Set{N}, Σ::Set{T}) where {N, T}
    if sym in Σ
        return TerminalSymbol{T}(sym)
    elseif sym in V
        return NonterminalSymbol{N}(sym)
    else
        throw(ArgumentError("symbol $(repr(sym)) appears in a production, but is neither a terminal nor nonterminal symbol"))
    end
end

val(S::AbstractGrammarSymbol) = S.val

###
### Productions
###

"""
    Production{N, T, E <: AbstractSemiringElement}

A single weighted grammar rule ``A ⇒ α`` with weight of semiring element type
`E`. The left-hand side `lhs` is a nonterminal of type `N`; the right-hand side
`rhs` is a sequence of tagged symbols, each either a `TerminalSymbol{T}` or a
`NonterminalSymbol{N}`.
"""
struct Production{N, T, E <: AbstractSemiringElement}
    lhs::N
    rhs::Vector{Union{TerminalSymbol{T}, NonterminalSymbol{N}}}
    weight::E

    Production{N,T,E}(lhs, rhs::AbstractVector, weight) where {N,T,E} =
        new{N,T,E}(lhs, rhs, weight)
end

Production(lhs::N, rhs::Vector{Union{TerminalSymbol{T}, NonterminalSymbol{N}}}, weight::E) where {N, T, E <: AbstractSemiringElement} =
    Production{N,T,E}(lhs, rhs, weight)

"""
    lhs(p::Production)

Return the left-hand-side nonterminal of production `p`.
"""
lhs(p::Production) = p.lhs

"""
    rhs(p::Production)

Return the right-hand side of production `p` as a vector of tagged symbols, each a
`TerminalSymbol` or a `NonterminalSymbol`. Apply [`val`](@ref) to a symbol to recover
its underlying value.
"""
rhs(p::Production) = p.rhs

"""
    weight(p::Production)

Return the semiring weight of production `p`.
"""
weight(p::Production) = p.weight

function compose(a::Production{N,T,E}, b::Production{N,T,E}) where {N,T,E}
    (length(a.rhs) == 1 && a.rhs[1].val == b.lhs) || throw(ArgumentError("$(a.lhs) ⇒ $(a.rhs) is not composable with $(b.lhs) ⇒ $(b.rhs)"))

    return Production(a.lhs, b.rhs, a.weight * b.weight)
end

function is_unit_production(production::Production)
    return (length(rhs(production)) == 1) && isa(first(rhs(production)), NonterminalSymbol)
end

function is_terminal_production(production::Production)
    return all(isa.(rhs(production), TerminalSymbol))
end

function construct_production(production::Tuple{N, AbstractVector}, V::Set{N}, Σ::Set{T}, semiring::AbstractSemiring) where {N, T}
    E = element_type(typeof(semiring))
    E === BooleanElement || throw(ArgumentError("semiring of element type $E requires explicit weights; production $production has none"))

    return construct_production((production..., one(BooleanElement)), V, Σ, semiring)
end

function construct_production(production::Tuple{N, AbstractVector, Any}, V::Set{N}, Σ::Set{T}, semiring::AbstractSemiring) where {N, T}
    lhs, rhs, weight = production
    E = element_type(typeof(semiring))
    return construct_production(lhs, rhs, lift(weight, E), V, Σ)
end

function construct_production(lhs::N, rhs::AbstractVector, weight::E, V::Set{N}, Σ::Set{T}) where {N, T, E <: AbstractSemiringElement}
    lhs ∈ V || throw(ArgumentError("$lhs is not a nonterminal symbol"))
    tagged_rhs = Union{TerminalSymbol{T}, NonterminalSymbol{N}}[tag_symbol(x, V, Σ) for x in rhs]
    return Production{N, T, E}(lhs, tagged_rhs, weight)
end

###
### Grammars
###

abstract type AbstractGrammar{N, T, E} end

"""
    ContextFreeGrammar{N, T, E}

A weighted context-free grammar with nonterminals of type `N`, terminals of type `T`,
and production weights of semiring element type `E`. Its fields are the
sets of [`nonterminals`](@ref) and [`terminals`](@ref), the vector of
[`productions`](@ref), and the [`start`](@ref) symbol.

# Constructors

    ContextFreeGrammar(productions, start; semiring = BooleanSemiring())
    ContextFreeGrammar(nonterminals, terminals, productions, start; semiring = BooleanSemiring())

Build a grammar from a collection of `productions`. Each production is a tuple
`(lhs, rhs)`—or `(lhs, rhs, weight)` for a non-Boolean `semiring` where `lhs` is a
nonterminal and `rhs` is a vector of symbols. In the two-argument form the terminal and nonterminal alphabets are
inferred from the productions; in the four-argument form they are given explicitly.

# Examples

```julia
G = ContextFreeGrammar(
    [(:S, [:NP, :VP]), (:NP, ["fish"]), (:VP, ["swim"])],
    :S,
)
```
"""
struct ContextFreeGrammar{N, T, E} <: AbstractGrammar{N, T, E}
    nonterminals::Set{N}
    terminals::Set{T}
    productions::Vector{Production{N,T,E}}
    start::N
end

function ContextFreeGrammar(productions::AbstractVector, start; semiring::AbstractSemiring = BooleanSemiring())
    N = typeof(start)
    nonterminals = N[]
    terminals = []
    for p ∈ productions
        symbols = [p[1]] ∪ p[2]
        nonterminals = nonterminals ∪ filter(s -> isa(s, N), symbols)
        terminals = terminals ∪ filter(s -> !isa(s, N), symbols)
    end
    T = typeof(first(terminals))
    all(s -> isa(s, T), terminals) || throw(ArgumentError("terminal symbols must all be of same type"))
    return ContextFreeGrammar(Vector{N}(nonterminals), Vector{T}(terminals), productions, start; semiring)
end

function ContextFreeGrammar(nonterminals::AbstractVector{N}, terminals::AbstractVector{T}, productions::AbstractVector, start::N; semiring::AbstractSemiring = BooleanSemiring()) where {N, T}
    V = Set(nonterminals)
    Σ = Set(terminals)

    overlap = intersect(V, Σ)
    isempty(overlap) || throw(ArgumentError("terminals and nonterminals must be disjoint; found common symbols: $overlap"))
    start ∈ V || throw(ArgumentError("start symbol $start is not a nonterminal symbol"))

    R = [construct_production(production, V, Σ, semiring) for production in productions]

    return ContextFreeGrammar(V, Σ, R, start)
end

# Convenience accessors

"""
    terminals(G::AbstractGrammar)

Return the set of terminal symbols of grammar `G`.
"""
terminals(G::AbstractGrammar) = G.terminals

"""
    nonterminals(G::AbstractGrammar)

Return the set of nonterminal symbols of grammar `G`.
"""
nonterminals(G::AbstractGrammar) = G.nonterminals

"""
    productions(G::AbstractGrammar)

Return the vector of [`Production`](@ref)s of grammar `G`.
"""
productions(G::AbstractGrammar) = G.productions

"""
    start(G::AbstractGrammar)

Return the start symbol of grammar `G`.
"""
start(G::AbstractGrammar) = G.start
semiring(::AbstractGrammar{N,T,E}) where {N,T,E} = semiring(E)

###
### CFG Manipulations
###

function adjacency_matrix(productions::AbstractVector{Production{N, T, E}}) where {N, T, E}
    all(is_unit_production.(productions)) || throw(ArgumentError("P may only contain unit productions"))

    # Generate vector of unique symbols
    symbols = collect(Set(lhs.(productions)) ∪ Set(val.(first.(rhs.(productions)))))
    n = length(symbols)

    A = zeros(E, n, n)
    for p ∈ productions
        i = findfirst(isequal(lhs(p)), symbols)
        j = findfirst(isequal(val(first(rhs(p)))), symbols)
        A[i,j] = weight(p)
    end

    return A, symbols
end

function adjacency_closure!(A::Matrix{E}) where E
    n = size(A)[1]

    # Perform A_ij ⟵ A_ij ⊕ (A_ik ⊗ star(A_kk) ⊗ A_kj)
    for k ∈ 1:n
        A[k,k] = star(A[k,k]) # Pivot 
        for i in 1:n                    # scale column k on the right
            i == k && continue # Skip pivot
            A[i,k] = A[i,k] * A[k,k]
        end
        for j in 1:n, i in 1:n          # reroute through k
            (i == k || j == k) && continue
            A[i,j] = A[i,j] + A[i,k] * A[k,j]
        end
        for j in 1:n                    # scale row k on the left
            j == k && continue
            A[k,j] = A[k,k] * A[k,j]
        end
    end

    return A
end

function unit_production_closure(P::AbstractVector{Production{N, T, E}}) where {N, T, E}
    A, symbols = adjacency_matrix(P)
    adjacency_closure!(A)
    return A, symbols
end

"""
    generating_symbols(cfg::AbstractGrammar)

Return the set of *generating* symbols of `cfg`: the terminals together with every
nonterminal that can derive a string of terminals. Computed by least-fixed-point
iteration, marking a nonterminal as generating once some production expands it into
already-generating symbols. Used by [`remove_useless_symbols`](@ref).
"""
function generating_symbols(cfg::AbstractGrammar)
    Σ = copy(terminals(cfg))
    R = productions(cfg)

    old_generating = Set{eltype(Σ)}()
    new_generating = Set(lhs.(filter(r -> val.(rhs(r)) ⊆ Σ, R)))
    while old_generating != new_generating
        old_generating = new_generating
        Σ = Σ ∪ old_generating
        new_generating = old_generating ∪ Set(lhs.(filter(r -> val.(rhs(r)) ⊆ Σ, R)))
    end
    return new_generating
end

"""
    reachable_symbols(cfg::AbstractGrammar)

Return the set of symbols *reachable* from the start symbol of `cfg`: those that
appear in some sentential form derivable from `start(cfg)`. Computed by least-fixed-point
iteration, starting from the start symbol and following productions whose left-hand
side is already reachable. Used by [`remove_useless_symbols`](@ref).
"""
function reachable_symbols(cfg::AbstractGrammar)
    S = start(cfg)
    old_reachable = Set{eltype(S)}()
    new_reachable = Set{eltype(S)}([S])
    R = productions(cfg)

    while old_reachable != new_reachable
        old_reachable = new_reachable
        for r ∈ R
            if lhs(r) ∈ old_reachable
                new_reachable = new_reachable ∪ val.(rhs(r))
            end
        end
    end

    return new_reachable
end

"""
    remove_useless_symbols(cfg::AbstractGrammar)

Return a new [`ContextFreeGrammar`](@ref) equivalent to `cfg` with all useless symbols
removed. A symbol is useful only if it is both [`generating`](@ref generating_symbols)
and [`reachable`](@ref reachable_symbols). Non-generating symbols (and the productions
mentioning them) are dropped first, then unreachable symbols are dropped from the
result; the order matters, so that reachability is assessed on the already-pruned
grammar.
"""
function remove_useless_symbols(cfg::AbstractGrammar)
    generating = generating_symbols(cfg)
    R′ = filter(r -> lhs(r) ∈ generating && all(s -> s isa TerminalSymbol || val(s) ∈ generating, rhs(r)), productions(cfg))
    reachable = reachable_symbols(ContextFreeGrammar(generating, terminals(cfg), R′, start(cfg)))
    R′ = filter(r -> lhs(r) ∈ reachable, R′)

    V′ = Set(lhs.(R′))
    Σ′ = filter(t -> t ∈ reachable, terminals(cfg)) # Intersection that preserves type

    return ContextFreeGrammar(V′, Σ′, R′, start(cfg))
end

###
### Pretty Printing
###

function Base.show(io::IO, production::Production)
    print(io, production.lhs, " ⇒ ")
    join(io, (sym.val for sym in production.rhs), " ")
end

function Base.show(io::IO, productions::AbstractVector{<:Production})
    for production in productions
        println(io)
        show(io, production)
    end
end
