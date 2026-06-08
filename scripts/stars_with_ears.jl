using ContextFreeGrammars

const R = [
            (:S,  [:NP, :VP],        1.0)
            (:PP, [:P, :NP],         1.0)
            (:VP, [:V, :NP],         0.7)
            (:VP, [:VP, :PP],        0.3)
            (:P,  ["with"],          1.0)
            (:V,  ["saw"],           1.0)
            (:NP, [:NP, :PP],        0.4)
            (:NP, ["astronomers"],   0.1)
            (:NP, ["ears"],          0.18)
            (:NP, ["saw"],           0.04)
            (:NP, ["stars"],         0.18)
            (:NP, ["telescopes"],    0.1)
        ]

function main(sentence)
    cfg = ContextFreeGrammar(R, :S; semiring = ProbabilisticSemiring())

    chart = cyk(sentence, cfg)
    
    @show inside("stars with ears", :NP, chart)
    @show val(chart)
    @show inside(sentence, :S, chart) == val(chart)
end

main("astronomers saw stars with ears")
