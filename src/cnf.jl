struct ChomskyNormalFormContextFreeGrammar{N,T,E<:AbstractSemiringElement} <: AbstractGrammar
    nonterminals::Set{N}
    terminals::Set{T}
    productions::Vector{Production{N,T,E}}
    start::N
end

# Conversion follows the procedure outline in
# Hopcroft, J.E. and Ullman, J.D., "Introduction to Automata Theory,
# Languages, and Computation," pp.92-94 Addison-Wesley, 1979.

function chomsky_normal_form(cfg::ContextFreeGrammar{N,T,E}) where {N,T,E<:AbstractSemiringElement}
    V′ = copy(nonterminals(cfg))
    Σ′ = copy(terminals(cfg))
    S′ = start(cfg)

    R′ = remove_unit_productions(productions(cfg)) # Remove unit production without mutation

    return ChomskyNormalFormContextFreeGrammar(V′, Σ′, R′, S′)
end

function remove_unit_productions(productions::AbstractVector{Production{N,T,E}}) where {N,T,E<:AbstractSemiringElement}
    is_unit = is_unit_production.(productions)
    is_terminal = is_terminal_production.(productions)
    terminal_productions = productions[is_terminal]

    R′ = productions[.!is_unit]
    
    A, symbols = unit_production_closure(productions[is_unit])

    for i ∈ eachindex(symbols), j ∈ eachindex(symbols)
        if !(A[i,j] === Base.zero(E))
            for production ∈ terminal_productions
                if lhs(production) == symbols[j]
                    push!(R′, Production(
                            symbols[i], 
                            rhs(production),
                            A[i,j] * weight(production)
                        ))
                end
            end
        end
    end

    return R′
end

function in_chomsky_normal_form(production::Production)
    rhs = production.rhs
    cond1 = length(rhs) == 1 && isa(rhs[1], TerminalSymbol)
    cond2 = length(rhs) == 2 && all(x -> isa(x, NonterminalSymbol), rhs)
    return (cond1 || cond2)
end

function in_chomsky_normal_form(cfg::ContextFreeGrammar)
    return all(in_chomsky_normal_form.(productions(cfg)))
end
