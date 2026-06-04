module ContextFreeGrammars

include("semirings.jl")

export AbstractSemiring, AbstractSemiringElement
export BooleanSemiring, BooleanElement
export ProbabilisticSemiring, ProbabilisticElement

export AbstractGrammar
export ContextFreeGrammar
export terminals, nonterminals, productions, start

###
### Grammars
###

abstract type AbstractGrammarSymbol end

struct TerminalSymbol{T} <: AbstractGrammarSymbol; val::T; end
struct NonterminalSymbol{N} <: AbstractGrammarSymbol; val::N; end

val(S::AbstractGrammarSymbol) = S.val

struct Production{N, T, E <: AbstractSemiringElement}
    lhs::N
    rhs::Vector{Union{TerminalSymbol{T}, NonterminalSymbol{N}}}
    weight::E

    Production{N,T,E}(lhs, rhs::AbstractVector, weight) where {N, T, E <: AbstractSemiringElement} =
        new{N,T,E}(lhs, rhs, weight)
end

Production(lhs::N, rhs::Vector{Union{TerminalSymbol{T}, NonterminalSymbol{N}}}, weight::E) where {N, T, E <: AbstractSemiringElement} =
    Production{N,T,E}(lhs, rhs, weight)

lhs(p::Production) = p.lhs
rhs(p::Production) = p.rhs
weight(p::Production) = p.weight

function compose(a::Production{N,T,E}, b::Production{N,T,E}) where {N,T,E}
    (length(a.rhs) == 1 && a.rhs[1].val == b.lhs) || throw(ArgumentError("$(a.lhs) ⇒ $(a.rhs) is not composable with $(b.lhs) ⇒ $(b.rhs)"))

    return Production(a.lhs, b.rhs, a.weight * b.weight)
end

abstract type AbstractGrammar end

struct ContextFreeGrammar{N, T, E} <:AbstractGrammar
    nonterminals::Set{N}
    terminals::Set{T}
    productions::Vector{Production{N,T,E}}
    start::N
end

terminals(G::AbstractGrammar) = G.terminals
nonterminals(G::AbstractGrammar) = G.nonterminals
productions(G::AbstractGrammar) = G.productions
start(G::AbstractGrammar) = G.start

function is_unit_production(production::Production)
    return (length(rhs(production)) == 1) && isa(first(rhs(production)), NonterminalSymbol)
end

function is_terminal_production(production::Production)
    return all(isa.(rhs(production), TerminalSymbol))
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

function construct_production(production::Tuple{N, AbstractVector}, V::Set{N}, Σ::Set{T}, semiring::AbstractSemiring) where {N, T}
    E = element_type(semiring)
    E === BooleanElement || throw(ArgumentError("semiring of element type $E requires explicit weights; production $production has none"))

    return construct_production((production..., one(BooleanElement)), V, Σ, semiring)
end

function construct_production(production::Tuple{N, AbstractVector, Any}, V::Set{N}, Σ::Set{T}, semiring::AbstractSemiring) where {N, T}
    lhs, rhs, weight = production
    E = element_type(semiring)
    return construct_production(lhs, rhs, lift(weight, E), V, Σ)
end

function construct_production(lhs::N, rhs::AbstractVector, weight::E, V::Set{N}, Σ::Set{T}) where {N, T, E <: AbstractSemiringElement}
    lhs ∈ V || throw(ArgumentError("$lhs is not a nonterminal symbol"))
    tagged_rhs = Union{TerminalSymbol{T}, NonterminalSymbol{N}}[tag_symbol(x, V, Σ) for x in rhs]
    return Production{N, T, E}(lhs, tagged_rhs, weight)
end

function tag_symbol(sym, V::Set{N}, Σ::Set{T}) where {N, T}
    if sym in Σ
        return TerminalSymbol{T}(sym)
    elseif sym in V
        return NonterminalSymbol{N}(sym)
    else
        throw(ArgumentError("symbol $(repr(sym)) appears in a production, but is neither a terminal nor nonterminal symbol"))
    end
end

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

function remove_useless_symbols(cfg::AbstractGrammar)
    generating = generating_symbols(cfg)
    R′ = filter(r -> lhs(r) ∈ generating, productions(cfg))
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

include("cnf.jl")

end # ContextFreeGrammars
