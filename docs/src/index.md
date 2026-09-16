# StackCollections.jl

This package implements a immutable bitstype collections. 
Currently, the following are implemented:

* `USet{U <: Unsigned} <: AbstractSet{UInt32}`: Integers as bit sets, which can contain intergers in `UInt32(0):UInt32(n)`, where `n == bitsizeof(U) - 1`.
* `UVector{U <: Unsigned} <: AbstractVector{Bool}`: Intergers as bit vectors.

These types are immutable, so instead of operations like `push!`, `pop!` and `append!`,
this package defines new non-mutating functions `push`, `pop` and `append`.

Operations on these types have been microoptimized.

See the details of each type implemented by this package in the sidebar.

## Examples
```jldoctest
vect = Bool[1, 0, 1, 1, 1, 0, 0, 1]
v = UVec{UInt16}(v)
@assert v == vect
@assert isbits(v)
@assert sizeof(v) == 2
@assert reverse(v) == reverse(vect)

v2 = push(v, false)
@assert v2 == push!(copy(vect), false)
```
