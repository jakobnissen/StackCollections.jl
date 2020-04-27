module StackCollections

struct Unsafe end
const unsafe = Unsafe()

abstract type AbstractStackSet <: AbstractSet{Int} end

include("stackvector.jl")
include("digitset.jl")
include("stackset.jl")

export StackVector, DigitSet, StackSet, setindex, push, pop, delete, complement, isdisjoint

end
