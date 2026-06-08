using ContextFreeGrammars

const R = [
        (:S,       [:NP, :VP]),
        (:VP,      [:V_intrans]),
        (:VP,      [:V_trans, :NP]),
        (:NP,      [:Det, :N]),
        (:NP,      [:Det, :N, :RC]),
        (:RC,      [:RC_SRC]),
        (:RC,      [:RC_ORC]),
        (:RC_SRC,  [:Comp, :VP]),
        (:RC_ORC,  [:Comp, :NP, :VP_gap]),
        (:VP_gap,  [:V_trans]),
        (:Det,     ["the"]),
        (:Det,     ["a"]),
        (:N,       ["reporter"]),
        (:N,       ["editor"]),
        (:N,       ["story"]),
        (:N,       ["article"]),
        (:Comp,    ["who"]),
        (:V_trans,   ["covered"]),
        (:V_trans,   ["hired"]),
        (:V_trans,   ["filed"]),
        (:V_trans,   ["saw"]),
        (:V_intrans, ["filed"]),
    ]

function main()
    G = ChomskyNormalFormContextFreeGrammar(R, :S)

    grammatical_sentences = [
        "the reporter who covered the story filed the article",
        "the reporter filed a article",
        "the editor saw a reporter who filed the story"
    ]
    ungrammatical_sentence = ""
    @show ContextFreeGrammars.val.(grammatical_sentences, Ref(G))
    @show ContextFreeGrammars.val(ungrammatical_sentence, G)
end

main()
