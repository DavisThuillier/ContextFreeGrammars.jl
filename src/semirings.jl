"""
    AbstractSemiring

Abstract supertype for the semirings used to weight grammar productions and parse
values. A semiring ``(K, ⊕, ⊗, 0̄, 1̄)`` supplies the algebraic structure over which
[`cyk`](@ref) accumulates inside values.

Each concrete semiring is a singleton type paired with an element type that subtypes
[`AbstractSemiringElement`](@ref). To define a custom semiring, create both types and
implement `element_type`, [`semiring`](@ref), `Base.:+`, `Base.:*`, `Base.zero`,
`Base.one`, and—if unit-production elimination is needed—`star` for the element type.

See also [`BooleanSemiring`](@ref), [`ProbabilisticSemiring`](@ref),
[`CountSemiring`](@ref).
"""
abstract type AbstractSemiring end

"""
    AbstractSemiringElement

Abstract supertype for the elements (weights) of an [`AbstractSemiring`](@ref).

A concrete subtype wraps a single value, retrievable with [`val`](@ref), and must
implement `Base.:+` (semiring addition `⊕`), `Base.:*` (semiring multiplication `⊗`),
`Base.zero` (the additive identity `0̄`), and `Base.one` (the multiplicative identity
`1̄`). A `star` method may also be supplied for the closure operations used when
removing unit productions (see [`remove_unit_productions`](@ref)).
"""
abstract type AbstractSemiringElement end

lift(x, ::Type{E}) where {E<:AbstractSemiringElement} = E(x) # Promotes a value to the corresponding element type
lift(x::E, ::Type{E}) where {E<:AbstractSemiringElement} = x # Idempotent protection for weights

"""
    val(x::AbstractSemiringElement)

Return the underlying value wrapped by the semiring element `x` (e.g. the `Bool`
inside a [`BooleanElement`](@ref) or the `Float64` inside a
[`ProbabilisticElement`](@ref)).
"""
val(x::E) where {E<:AbstractSemiringElement} = x.val

Base.zero(x::AbstractSemiringElement) = zero(typeof(x)) # Instance-level fallbacks to the type methods
Base.one(x::AbstractSemiringElement)  = one(typeof(x))

"""
    semiring(x::AbstractSemiringElement)
    semiring(::Type{<:AbstractSemiringElement})
    semiring(G::AbstractGrammar)

Return the [`AbstractSemiring`](@ref) singleton type associated with a semiring
element, an element type, or a grammar `G`. For a grammar this is the semiring whose
elements weight its productions.
"""
semiring(x::AbstractSemiringElement) = semiring(typeof(x)) # The semiring type a weight belongs to

###
### Standard Semiring Definitions
###

"""
    BooleanSemiring()

The Boolean semiring ``(\\{0,1\\}, ∨, ∧, 0, 1)`` whose elements are
[`BooleanElement`](@ref)s. Parsing under this semiring answers the recognition
question: [`val`](@ref) of the resulting chart is `true` exactly when the input is
in the language of the grammar. It is the default semiring throughout the package.
"""
struct BooleanSemiring <: AbstractSemiring end

"""
    BooleanElement(val::Bool)

An element of the [`BooleanSemiring`](@ref). Addition is logical OR, multiplication
is logical AND, `zero` is `false`, and `one` is `true`.
"""
struct BooleanElement <: AbstractSemiringElement; val::Bool; end

element_type(::Type{BooleanSemiring}) = BooleanElement
Base.:+(a::BooleanElement, b::BooleanElement) = BooleanElement(a.val || b.val)
Base.:*(a::BooleanElement, b::BooleanElement) = BooleanElement(a.val && b.val)
Base.zero(::Type{BooleanElement}) = BooleanElement(false)
Base.one(::Type{BooleanElement})  = BooleanElement(true) 
star(::BooleanElement) = BooleanElement(true)
semiring(::Type{BooleanElement}) = BooleanSemiring

"""
    ProbabilisticSemiring()

The probabilistic (inside) semiring ``([0, ∞), +, ×, 0, 1)`` whose elements are
[`ProbabilisticElement`](@ref)s. Used with a weighted grammar (e.g. a PCFG), parsing
under this semiring makes [`val`](@ref) of the chart the total probability mass of
all derivations of the input.
"""
struct ProbabilisticSemiring <: AbstractSemiring end

"""
    ProbabilisticElement(val::Float64)

An element of the [`ProbabilisticSemiring`](@ref). Addition and multiplication are
the usual real `+` and `×`, `zero` is `0.0`, and `one` is `1.0`. The closure
`star(a)` is `1 / (1 - a)`.
"""
struct ProbabilisticElement <: AbstractSemiringElement; val::Float64; end
star(a::ProbabilisticElement) = ProbabilisticElement(1 / (1 - a.val))

element_type(::Type{ProbabilisticSemiring}) = ProbabilisticElement
Base.:+(a::ProbabilisticElement, b::ProbabilisticElement) = ProbabilisticElement(a.val + b.val)
Base.:*(a::ProbabilisticElement, b::ProbabilisticElement) = ProbabilisticElement(a.val * b.val)
Base.zero(::Type{ProbabilisticElement}) = ProbabilisticElement(0.0)
Base.one(::Type{ProbabilisticElement})  = ProbabilisticElement(1.0)
semiring(::Type{ProbabilisticElement}) = ProbabilisticSemiring

struct InfInt end
const ∞ = InfInt()
Base.show(io::IO, ::InfInt) = show(io, "∞")

"""
    CountSemiring()

The counting semiring ``(ℕ ∪ \\{∞\\}, +, ×, 0, 1)`` whose elements are
[`CountElement`](@ref)s. Parsing under this semiring makes [`val`](@ref) of the chart
the number of distinct derivations of the input, which is reported as `∞` when the
grammar admits infinitely many.
"""
struct CountSemiring <: AbstractSemiring end

"""
    CountElement(val::Union{Int,InfInt})

An element of the [`CountSemiring`](@ref), holding a non-negative integer count or the
sentinel `∞`. Addition and multiplication are the usual integer `+` and `×`, `zero`
is `0`, and `one` is `1`. The closure `star(a)` is `one` when `a` is zero and `∞`
otherwise.
"""
struct CountElement <: AbstractSemiringElement; val::Union{Int,InfInt}; end
star(a::CountElement) = iszero(a) ? one(typeof(a)) : CountElement(∞)

element_type(::Type{CountSemiring}) = CountElement
Base.:+(a::CountElement, b::CountElement) = CountElement(a.val + b.val)
Base.:*(a::CountElement, b::CountElement) = CountElement(a.val * b.val)
Base.zero(::Type{CountElement}) = CountElement(0)
Base.one(::Type{CountElement})  = CountElement(1)
semiring(::Type{CountElement}) = CountSemiring
