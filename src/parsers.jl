tri(n) = (n * (n - 1)) ÷ 2
@inline tri_index(i, j) = tri(j) + i + 1

struct Chart{E}
    vals::Matrix{E}
    n::Int # String length
end

Chart{E}(n::Int, m::Int) where {E} = Chart(zeros(E, tri(n + 1), m), n)

function Base.setindex!(c::Chart{E}, val::E, i::Int, j::Int, k::Int) where {E}
    c.vals[tri_index(i, j), k] = val
end
Base.getindex(c::Chart{E}, i::Int, j::Int, k::Int) where {E} = c.vals[tri_index(i, j), k]

# Goodman, semiring parsing

function cyk(input::AbstractVector{T}, grammar::AbstractGrammar{N,T,E}) where {N, T, E}
    in_chomsky_normal_form(grammar) || throw(ArgumentError(" grammar must be in ChomskyNormalForm"))
    n = length(input)

    V = collect(nonterminals(grammar)) # Make indexed vector of symbols
    Σ = collect(terminals(grammar)) # Make indexed vector of symbols
    m = length(V)

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

    chart = Chart{E}(n, m) # Look-up table for nonterminal associated to terminal production

    for i ∈ 1:n
        for (A, a, w) ∈ terminal_idx_weights
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

function cyk(sentence::String, grammar::AbstractGrammar; dlm = " ")
    words = String.(split(sentence, dlm))
    return cyk(words, grammar)
end
