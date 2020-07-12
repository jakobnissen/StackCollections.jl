module StackCollections

struct Unsafe end
const unsafe = Unsafe()

abstract type AbstractStackSet <: AbstractSet{Int} end
Base.hasfastin(::Type{AbstractStackSet}) = true

include("stackvector.jl")
include("digitset.jl")
include("stackset.jl")
include("onehotvector.jl")

export StackVector, DigitSet, StackSet, setindex, push, pop, delete,
       complement, isdisjoint, OneHotVector, reverse

end
