module t

# StackSet, no params, 0-63
# StackBitSet, no params, contain StackSet and offset
# StackVector, length param, as now implemented

struct Unsafe end
const unsafe = Unsafe()

abstract type AbstractStackSet <: AbstractSet{Int} end

include("stackarray.jl")
include("stackset.jl")
include("stackbitset.jl")

export StackArray, StackBitSet, setindex, StackSet, push, delete, complement, isdisjoint

end
