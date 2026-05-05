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
    R′, V′ = replace_long_productions(R′, nonterminals(V′)) # Split A → X₁…Xₙ into A → X₁A₁, A₁ → X₂A₂, etc.
    R′, V′ = replace_terminals_in_binaries(R′, V′)

    # for rule ∈ R
    #     in_chomsky_normal_form(rule) && push!(R′, rule)
    # end
    return ChomskyNormalFormContextFreeGrammar(V′, Σ′, R′, S′)
end

function is_unit_production(rule::Rule)
    return length(rule.rhs) == 1 && isa(rule.rhs, NonterminalSymbol)
end

#FIXME: Implement algorithm to remove unit productions
function remove_unit_productions(rules::Vector{Rule})
    return rules 
end

#FIXME: Implement algorithm to replace long productions
function replace_long_productions(rules::Vector{Rule}, nonterminals::Set{N}) where {N}
    return rules, nonterminals
end

#FIXME: Implement algorithm to remove unit productions
function replace_long_productions(rules::Vector{Rule}, nonterminals::Set{N}) where {N}
    return rules, nonterminals
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
