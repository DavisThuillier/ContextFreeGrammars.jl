using ContextFreeGrammars
using Random

const R = [
            (:S,  [:N],                1),
            (:N, [:N, "and", :N],      1),
            (:N, ["fish"],             1),
            (:N, ["eggs"],             1),
            (:N, ["bread"],            1)
        ]

function main(N = 20)
    G = ChomskyNormalFormContextFreeGrammar(R, :S; semiring = CountSemiring()) 
    
    nouns = delete!(copy(terminals(G)), "and")

    sentence = "fish"
    catalan_numbers = Vector{Int}(undef, N)
    for i ∈ 1:N
        catalan_numbers[i] = val(sentence, G)
        sentence *= " and " * rand(nouns)
    end

    println(catalan_numbers)
end

main(20)
