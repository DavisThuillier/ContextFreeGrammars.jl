module ContextFreeGrammars

export AbstractSemiring, AbstractSemiringElement
export BooleanSemiring, BooleanElement
export ProbabilisticSemiring, ProbabilisticElement

export AbstractGrammar
export ContextFreeGrammar
export terminals, nonterminals, rules, start

abstract type AbstractSemiring end
abstract type AbstractSemiringElement end

lift(x, ::Type{E}) where {E<:AbstractSemiringElement} = E(x) # Promotes a value to the corresponding element type
lift(x::E, ::Type{E}) where {E<:AbstractSemiringElement} = x # Idempotent protection for weights

###
### Standard Semiring Definitions
###

struct BooleanSemiring <: AbstractSemiring end
struct BooleanElement <: AbstractSemiringElement; val::Bool; end

element_type(::BooleanSemiring) = BooleanElement
Base.:+(a::BooleanElement, b::BooleanElement) = BooleanElement(a.val || b.val)
Base.:*(a::BooleanElement, b::BooleanElement) = BooleanElement(a.val && b.val)
Base.zero(::Type{BooleanElement}) = BooleanElement(false)
Base.one(::Type{BooleanElement})  = BooleanElement(true) 

struct ProbabilisticSemiring <: AbstractSemiring end
struct ProbabilisticElement <: AbstractSemiringElement; val::Bool; end

element_type(::ProbabilisticSemiring) = ProbabilisticElement
Base.:+(a::ProbabilisticElement, b::ProbabilisticElement) = ProbabilisticElement(a.val + b.val)
Base.:*(a::ProbabilisticElement, b::ProbabilisticElement) = ProbabilisticElement(a.val * b.val)
Base.zero(::Type{ProbabilisticElement}) = ProbabilisticElement(0.0)
Base.one(::Type{ProbabilisticElement})  = ProbabilisticElement(1.0) 

###
### Grammars
###

abstract type AbstractGrammarSymbol end

struct TerminalSymbol{T} <: AbstractGrammarSymbol; val::T; end 
struct NonterminalSymbol{N} <: AbstractGrammarSymbol; val::N; end 

struct Rule{N, T, E <: AbstractSemiringElement}
    lhs::N
    rhs::Vector{Union{TerminalSymbol{T}, NonterminalSymbol{N}}}
    weight::E
end

abstract type AbstractGrammar end

struct ContextFreeGrammar{N, T, E} <:AbstractGrammar
    nonterminals::Set{N}
    terminals::Set{T}
    rules::Vector{Rule{N,T,E}}
    start::N
end

terminals(G::AbstractGrammar) = G.terminals
nonterminals(G::AbstractGrammar) = G.nonterminals 
rules(G::AbstractGrammar) = G.rules
start(G::AbstractGrammar) = G.start

function ContextFreeGrammar(nonterminals::AbstractVector{N}, terminals::AbstractVector{T}, rules, start::N; semiring::AbstractSemiring = BooleanSemiring()) where {N, T}
    V = Set(nonterminals)
    Σ = Set(terminals)

    overlap = intersect(V, Σ)
    isempty(overlap) || throw(ArgumentError("terminals and nonterminals must be disjoint; found common symbols: $overlap"))
    start ∈ V || throw(ArgumentError("start symbol $start is not a nonterminal symbol"))

    R = [construct_rule(rule, V, Σ, semiring) for rule in rules]

    return ContextFreeGrammar(V, Σ, R, start)
end

function construct_rule(rule::Tuple{N, AbstractVector}, V::Set{N}, Σ::Set{T}, semiring::AbstractSemiring) where {N, T}
    E = element_type(semiring)
    E === BooleanElement || throw(ArgumentError("semiring of element type $E requires explicit weights; rule $rule has none"))

    return construct_rule((rule..., one(BooleanElement)), V, Σ, semiring)
end

function construct_rule(rule::Tuple{N, AbstractVector, Any}, V::Set{N}, Σ::Set{T}, semiring::AbstractSemiring) where {N, T}
    lhs, rhs, weight = rule
    E = element_type(semiring)
    return construct_rule(lhs, rhs, lift(weight, E), V, Σ)
end

function construct_rule(lhs::N, rhs::AbstractVector, weight::E, V::Set{N}, Σ::Set{T}) where {N, T, E <: AbstractSemiringElement}
    lhs ∈ V || throw(ArgumentError("$lhs is not a nonterminal symbol"))
    tagged_rhs = Union{TerminalSymbol{T}, NonterminalSymbol{N}}[tag_symbol(x, V, Σ) for x in rhs]
    return Rule{N, T, E}(lhs, tagged_rhs, weight)
end

function tag_symbol(sym, V::Set{N}, Σ::Set{T}) where {N, T}
    if sym in Σ
        return TerminalSymbol{T}(sym)
    elseif sym in V
        return NonterminalSymbol{N}(sym)
    else
        throw(ArgumentError("symbol $(repr(sym)) appears in a rule, but is neither a terminal nor nonterminal symbol"))
    end
end

###
### Pretty Printing
###

function Base.show(io::IO, rule::Rule)
    print(io, rule.lhs, " ⇒ ")
    join(io, (sym.val for sym in rule.rhs), " ")
end

function Base.show(io::IO, rules::AbstractVector{<:Rule})
    for rule in rules
        println(io)
        show(io, rule)
    end
end

include("cnf.jl")

end # ContextFreeGrammars
