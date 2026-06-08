using ContextFreeGrammars
using Test

using ContextFreeGrammars: abstract_terminals, binarize_productions, fresh_nonterminal

@testset "ContextFreeGrammars.jl" begin
    @testset "Conversion reaches Chomsky normal form" begin
        V = [:S, :A, :B, :C]
        Σ = ["a", "b", "c"]
        R = [
            (:S, [:A, :B, :C]),   # pure binarization
            (:S, ["a", :B]),      # terminal abstraction in a length-2 body
            (:A, ["a", :B, :C]),  # both, reusing the abstraction of "a"
            (:A, ["a"]),          # single terminal: already CNF, must pass through
            (:B, ["b"]),
            (:C, ["c"]),
        ]
        cnf = ChomskyNormalFormContextFreeGrammar(ContextFreeGrammar(V, Σ, R, :S))

        @test in_chomsky_normal_form(cnf)
        @test all(p -> length(rhs(p)) ≤ 2, productions(cnf))
    end

    @testset "Terminal abstraction reuses one nonterminal per terminal" begin
        # "a" occurs in two length-≥2 bodies but must map to a single fresh nonterminal.
        V = [:S, :B, :C]
        Σ = ["a", "b", "c"]
        R = [
            (:S, ["a", :B]),
            (:S, ["a", :C]),
            (:B, ["b"]),
            (:C, ["c"]),
        ]
        g = abstract_terminals(ContextFreeGrammar(V, Σ, R, :S))

        @test length(nonterminals(g)) == length(V) + 1                 # one new nonterminal
        @test count(p -> [s.val for s in rhs(p)] == ["a"], productions(g)) == 1  # one Cₐ ⇒ a
    end

    @testset "Binarization preserves weights (probabilistic)" begin
        V = [:S, :A, :B, :C]
        Σ = ["a", "b", "c"]
        R = [
            (:S, [:A, :B, :C], 0.5),
            (:A, ["a"], 1.0),
            (:B, ["b"], 1.0),
            (:C, ["c"], 1.0),
        ]
        cnf = ChomskyNormalFormContextFreeGrammar(
            ContextFreeGrammar(V, Σ, R, :S; semiring = ProbabilisticSemiring()))

        @test in_chomsky_normal_form(cnf)
        # The 0.5 weight lands on exactly one production of the binarized chain; the rest
        # carry unit weight, so the product along the chain equals the original 0.5.
        @test count(p -> weight(p) == ProbabilisticElement(0.5), productions(cnf)) == 1
        @test count(p -> weight(p) == ProbabilisticElement(1.0), productions(cnf)) ==
              length(productions(cnf)) - 1
    end

    @testset "fresh_nonterminal" begin
        @test fresh_nonterminal(Symbol, Set([:X1, :X2]), Set{String}()) == :X3
        @test fresh_nonterminal(String, Set(["X1"]), Set{String}()) == "X2"
        # A terminal clash only matters when the terminal type matches the nonterminal type.
        @test fresh_nonterminal(Symbol, Set{Symbol}(), Set([:X1])) == :X2
        @test fresh_nonterminal(Symbol, Set{Symbol}(), Set(["X1"])) == :X1
        # An unsupported nonterminal type fails informatively.
        @test_throws ArgumentError fresh_nonterminal(Int, Set{Int}(), Set{Int}())
    end
end
