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
    R′ = remove_unit_productions(productions(cfg)) # Remove unit productions without mutation
    g = ContextFreeGrammar(copy(nonterminals(cfg)), copy(terminals(cfg)), R′, start(cfg))

    g = remove_useless_symbols(g) # Discard non-generating and unreachable symbols
    g = abstract_terminals(g)     # Replace terminals in length-≥2 bodies with fresh nonterminals
    g = binarize_productions(g)   # Split length-≥3 bodies into a chain of binary productions

    return ChomskyNormalFormContextFreeGrammar(nonterminals(g), terminals(g), productions(g), start(g))
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

###
### Fresh Symbol Generation
###

# Mint a value of type N that is a member of neither the nonterminals V nor the
# terminals Σ, for use as a new nonterminal during Chomsky normal form conversion.
# Support a new nonterminal type by defining an additional method.
fresh_nonterminal(::Type{N}, V, Σ; prefix = "X") where {N} =
    throw(ArgumentError("Chomsky normal form conversion must mint fresh nonterminals of type $N; define a method `fresh_nonterminal(::Type{$N}, V, Σ; prefix)`"))

function fresh_nonterminal(::Type{Symbol}, V, Σ; prefix = "X")
    check_Σ = eltype(Σ) === Symbol # A fresh symbol can clash with a terminal only if the terminals are Symbols too
    i = 1
    while (s = Symbol(prefix, i)) ∈ V || (check_Σ && s ∈ Σ)
        i += 1
    end
    return Symbol(prefix, i)
end

function fresh_nonterminal(::Type{String}, V, Σ; prefix = "X")
    check_Σ = eltype(Σ) === String
    i = 1
    while (s = string(prefix, i)) ∈ V || (check_Σ && s ∈ Σ)
        i += 1
    end
    return string(prefix, i)
end

###
### Terminal Abstraction and Binarization
###

# Replace every terminal in a production body of length ≥ 2 with a fresh nonterminal
# Cₐ, adding a production Cₐ ⇒ a of unit weight. A single Cₐ is reused for all
# occurrences of a given terminal a. Bodies of length 1 (A ⇒ a) are already in
# Chomsky normal form and pass through untouched.
function abstract_terminals(cfg::ContextFreeGrammar{N,T,E}) where {N,T,E<:AbstractSemiringElement}
    V = copy(nonterminals(cfg))
    Σ = terminals(cfg)
    R′ = Production{N,T,E}[]
    terminal_nt = Dict{T,N}() # Maps a terminal a to its abstracting nonterminal Cₐ

    for p ∈ productions(cfg)
        body = rhs(p)
        if length(body) < 2
            push!(R′, p)
            continue
        end

        new_body = Union{TerminalSymbol{T},NonterminalSymbol{N}}[]
        for sym ∈ body
            if sym isa TerminalSymbol
                C = get!(terminal_nt, val(sym)) do
                    c = fresh_nonterminal(N, V, Σ; prefix = "N")
                    push!(V, c)
                    c
                end
                push!(new_body, NonterminalSymbol{N}(C))
            else
                push!(new_body, sym)
            end
        end
        push!(R′, Production{N,T,E}(lhs(p), new_body, weight(p))) # Original weight is preserved
    end

    for (a, C) ∈ terminal_nt # Emit one Cₐ ⇒ a production per abstracted terminal
        push!(R′, Production{N,T,E}(C, Union{TerminalSymbol{T},NonterminalSymbol{N}}[TerminalSymbol{T}(a)], one(E)))
    end

    return ContextFreeGrammar(V, copy(Σ), R′, start(cfg))
end

# Split every production A ⇒ B₁B₂…Bₖ whose body has length k ≥ 3 (and, after
# abstract_terminals, is all nonterminals) into a right-branching chain of k-1 binary
# productions introducing k-2 fresh nonterminals: A ⇒ B₁D₁, D₁ ⇒ B₂D₂, …, D_{k-2} ⇒ B_{k-1}Bₖ.
# The original weight is carried by the first production of the chain and the rest carry
# unit weight, so the product of weights along the chain is preserved.
function binarize_productions(cfg::ContextFreeGrammar{N,T,E}) where {N,T,E<:AbstractSemiringElement}
    V = copy(nonterminals(cfg))
    Σ = terminals(cfg)
    R′ = Production{N,T,E}[]

    for p ∈ productions(cfg)
        body = rhs(p)
        if length(body) ≤ 2
            push!(R′, p)
            continue
        end

        k = length(body)
        D = N[] # The k-2 fresh nonterminals D₁ … D_{k-2}
        for _ ∈ 1:(k - 2)
            d = fresh_nonterminal(N, V, Σ; prefix = "X")
            push!(V, d)
            push!(D, d)
        end

        heads = vcat(lhs(p), D) # Left-hand side of each of the k-1 new productions
        for i ∈ 1:(k - 1)
            tail = i < k - 1 ? NonterminalSymbol{N}(D[i]) : body[i + 1]
            new_body = Union{TerminalSymbol{T},NonterminalSymbol{N}}[body[i], tail]
            push!(R′, Production{N,T,E}(heads[i], new_body, i == 1 ? weight(p) : one(E)))
        end
    end

    return ContextFreeGrammar(V, copy(Σ), R′, start(cfg))
end

###
### Chomsky Normal Form Predicate
###

function in_chomsky_normal_form(production::Production)
    rhs = production.rhs
    cond1 = length(rhs) == 1 && isa(rhs[1], TerminalSymbol)
    cond2 = length(rhs) == 2 && all(x -> isa(x, NonterminalSymbol), rhs)
    return (cond1 || cond2)
end

function in_chomsky_normal_form(cfg::AbstractGrammar)
    return all(in_chomsky_normal_form.(productions(cfg)))
end
