struct ChomskyNormalFormContextFreeGrammar{N,T,E<:AbstractSemiringElement} <: AbstractGrammar
    nonterminals::Set{N}
    terminals::Set{T}
    rules::Vector{Rule{N,T,E}}
    start::N
end

# Conversion follows the procedure outline in
# Hopcroft, J.E. and Ullman, J.D., "Introduction to Automata Theory,
# Languages, and Computation," pp.92-94 Addison-Wesley, 1979.

function chomsky_normal_form(cfg::ContextFreeGrammar{N,T,E}) where {N,T,E<:AbstractSemiringElement}
    Σ′ = copy(terminals(cfg))
    S′ = start(cfg)
    
    R′ = remove_unit_productions(rules(cfg)) # Remove unit production without mutation
    
    return ChomskyNormalFormContextFreeGrammar(V′, Σ′, R′, S′)
end

function remove_unit_productions(rules::AbstractVector{Rule})
    
end

function derives(A::NonterminalSymbol{T}, B::NonterminalSymbol{T}, cfg::AbstractGrammar) where {T}
    A ∈ nonterminals(cfg) && B ∈ nonterminals(cfg) || throw(ArgumentError("$A and $B must both be nonterminals of $cfg"))

    productions = rules(cfg)
    unit_productions = productions[is_unit_production.(productions)]
    
    
end

function in_chomsky_normal_form(rule::Rule)
    rhs = rule.rhs
    cond1 = length(rhs) == 1 && isa(rhs[1], TerminalSymbol)
    cond2 = length(rhs) == 2 && all(x -> isa(x, NonterminalSymbol), rhs)
    return (cond1 || cond2)
end

function in_chomsky_normal_form(cfg::ContextFreeGrammar)
    return all(in_chomsky_normal_form.(rules(cfg)))
end
