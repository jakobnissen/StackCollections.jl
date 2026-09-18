module StackCollections

# By masking the shift, these function suppress the branches when the shift is
# >= bitwidth(x).
@inline left_shift(x::Integer, s::Signed) = left_shift(x, s % UInt32)
@inline function left_shift(x::Integer, u::Unsigned)
    return x << rem(u, bitwidth(x) % UInt32)
end

@inline right_shift(x::Integer, s::Signed) = right_shift(x, s % UInt32)
@inline function right_shift(x::Integer, u::Unsigned)
    return x >>> rem(u, bitwidth(x) % UInt32)
end

# Core.bitsizeof was added in Julia 1.14. Before this version, all primitive
# types were multiple of 8 bits
@static if VERSION >= v"1.14.0-DEV.2710"
    bitwidth(T::Type{<:Integer}) = Core.bitsizeof(T)
else
    bitwidth(T::Type{<:Integer}) = 8 * sizeof(T)
end

bitwidth(::U) where {U <: Integer} = bitwidth(U)

# Get a bitmask where only the lowest mod(n, bitwidth(U)) are set
function bitmask(::Type{U}, n::Integer) where {U <: Unsigned}
    o = one(U)
    return left_shift(o, n) - o
end

"""
    pop(collection::Union{Uset, UVec}) -> (new_collection, item)

Create a new collection of the same type as the input, but with the last element
removed. The new collection and the removed element is returned as a tuple.

If collection is empty, throw an `ArgumentError`. The check can be disabled locally
with `@inbounds`, similar to `BoundsError`s.

```jldoctest
julia> (v2, element) = pop(UVec{UInt16}([1, 0]));

julia> element
false

julia> v2 === UVec{UInt16}([1])
true
```
"""
function pop end

"""
    popfirst(collection::Union{Uset, UVec}) -> (new_collection, item)

Create a new collection of the same type as the input, but with the first element
removed. The new collection and the removed element is returned as a tuple.

If collection is empty, throw an `ArgumentError`. The check can be disabled locally
with `@inbounds`, similar to `BoundsError`s.

```jldoctest
julia> (v2, element) = popfirst(UVec{UInt16}([1, 0]));

julia> element
true

julia> v2 === UVec{UInt16}([0])
true
```
"""
function popfirst end

include("uset.jl")
include("uvec.jl")

public maximum_member

export USet,
    UVec,
    push,
    pushfirst,
    pop,
    popfirst,
    deleteat,
    append,
    insert,
    capacity,
    uset_from_integer,
    can_contain

end # module
