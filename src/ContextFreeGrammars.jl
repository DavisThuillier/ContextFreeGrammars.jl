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


struct Production{N, T, E <: AbstractSemiringElement}
    lhs::N
    rhs::Vector{Union{TerminalSymbol{T}, NonterminalSymbol{N}}}
    weight::E

    Production{N,T,E}(lhs, rhs::AbstractVector, weight) where {N, T, E <: AbstractSemiringElement} =
        new{N,T,E}(lhs, rhs, weight)
end

Production(lhs::N, rhs::Vector{Union{TerminalSymbol{T}, NonterminalSymbol{N}}}, weight::E) where {N, T, E <: AbstractSemiringElement} =
    Production{N,T,E}(lhs, rhs, weight)

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
    return length(production.rhs) == 1 && isa(production.rhs[1], NonterminalSymbol)
end

function ContextFreeGrammar(nonterminals::AbstractVector{N}, terminals::AbstractVector{T}, productions, start::N; semiring::AbstractSemiring = BooleanSemiring()) where {N, T}
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
