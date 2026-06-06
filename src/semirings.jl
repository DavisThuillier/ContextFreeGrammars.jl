abstract type AbstractSemiring end
abstract type AbstractSemiringElement end

lift(x, ::Type{E}) where {E<:AbstractSemiringElement} = E(x) # Promotes a value to the corresponding element type
lift(x::E, ::Type{E}) where {E<:AbstractSemiringElement} = x # Idempotent protection for weights

val(x::E) where {E<:AbstractSemiringElement} = x.val

semiring(x::AbstractSemiringElement) = semiring(typeof(x)) # The semiring type a weight belongs to

###
### Standard Semiring Definitions
###

struct BooleanSemiring <: AbstractSemiring end
struct BooleanElement <: AbstractSemiringElement; val::Bool; end

element_type(::Type{BooleanSemiring}) = BooleanElement
Base.:+(a::BooleanElement, b::BooleanElement) = BooleanElement(a.val || b.val)
Base.:*(a::BooleanElement, b::BooleanElement) = BooleanElement(a.val && b.val)
Base.zero(::Type{BooleanElement}) = BooleanElement(false)
Base.one(::Type{BooleanElement})  = BooleanElement(true) 
star(::BooleanElement) = BooleanElement(true)
semiring(::Type{BooleanElement}) = BooleanSemiring

struct ProbabilisticSemiring <: AbstractSemiring end
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

struct CountSemiring <: AbstractSemiring end
struct CountElement <: AbstractSemiringElement; val::Union{Int,InfInt}; end
star(a::CountElement) = iszero(a) ? one(typeof(a)) : CountElement(∞)

element_type(::Type{CountSemiring}) = CountElement
Base.:+(a::CountElement, b::CountElement) = CountElement(a.val + b.val)
Base.:*(a::CountElement, b::ProbabilisticElement) = CountElement(a.val * b.val)
Base.zero(::Type{CountElement}) = CountElement(0)
Base.one(::Type{CountElement})  = CountElement(1)
semiring(::Type{CountElement}) = CountSemiring
