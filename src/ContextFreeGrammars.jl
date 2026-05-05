module ContextFreeGrammars

export AbstractSemiring, AbstractSemiringElement
export BooleanSemiring, BooleanElement
export ProbabilisticSemiring, ProbabilisticElement

export AbstractGrammar
export ContextFreeGrammar
export terminals, nonterminals, rules, start

abstract type AbstractSemiring end
abstract type AbstractSemiringElement end

###
### Standard Semiring Definitions
###

struct BooleanSemiring <: AbstractSemiring end
struct BooleanElement <: AbstractSemiringElement; val::Bool; end
Base.:+(a::BooleanElement, b::BooleanElement) = BooleanElement(a.val || b.val)
Base.:*(a::BooleanElement, b::BooleanElement) = BooleanElement(a.val && b.val)
Base.zero(::Type{BooleanElement}) = BooleanElement(false)
Base.one(::Type{BooleanElement})  = BooleanElement(true) 

struct ProbabilisticSemiring <: AbstractSemiring end
struct ProbabilisticElement <: AbstractSemiringElement; val::Bool; end
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

struct Rule{T, N, E <: AbstractSemiringElement}
    lhs::N
    rhs::Vector{Union{TerminalSymbol{T}, NonterminalSymbol{N}}}
    weight::E
end

abstract type AbstractGrammar end

struct ContextFreeGrammar{T, N, E}
    terminals::Set{T}
    nonterminals::Set{N}
    rules::Rule{T,N,E}
    start::N
end

terminals(G::AbstractGrammar) = G.terminals
nonterminal(G::AbstractGrammar) = G.nonterminals 
rules(G::AbstractGrammar) = G.rules
start(G::AbstractGrammar) = G.start

end # ContextFreeGrammars
