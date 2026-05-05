abstract type AbstractSemiring end
abstract type AbstractSemiringElement end

lift(x, ::Type{E}) where {E<:AbstractSemiringElement} = E(x) # Promotes a value to the corresponding element type
lift(x::E, ::Type{E}) where {E<:AbstractSemiringElement} = x # Idempotent protection for weights

###
### Standard Semiring Definitions
###

struct BooleanSemiring <: AbstractSemiring end
struct BooleanElement <: AbstractSemiringElement; val::Bool; end

element_type(::BooleanSemiring) = BooleanElement
Base.:+(a::BooleanElement, b::BooleanElement) = BooleanElement(a.val || b.val)
Base.:*(a::BooleanElement, b::BooleanElement) = BooleanElement(a.val && b.val)
Base.zero(::Type{BooleanElement}) = BooleanElement(false)
Base.one(::Type{BooleanElement})  = BooleanElement(true) 

struct ProbabilisticSemiring <: AbstractSemiring end
struct ProbabilisticElement <: AbstractSemiringElement; val::Bool; end

element_type(::ProbabilisticSemiring) = ProbabilisticElement
Base.:+(a::ProbabilisticElement, b::ProbabilisticElement) = ProbabilisticElement(a.val + b.val)
Base.:*(a::ProbabilisticElement, b::ProbabilisticElement) = ProbabilisticElement(a.val * b.val)
Base.zero(::Type{ProbabilisticElement}) = ProbabilisticElement(0.0)
Base.one(::Type{ProbabilisticElement})  = ProbabilisticElement(1.0) 
