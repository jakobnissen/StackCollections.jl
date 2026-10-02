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

# Set only the zero-based bit position i, with the same wrapping as left_shift.
@inline singlebit(::Type{U}, i::Integer) where {U <: Unsigned} = left_shift(one(U), i)

# Return the zero-based position of the highest set bit, or -1 for zero.
@inline highestbit(x::Integer) = bitwidth(x) - leading_zeros(x) - 1

# Get a bitmask where only the lowest mod(n, bitwidth(U)) are set
function bitmask(::Type{U}, n::Integer) where {U <: Unsigned}
    return singlebit(U, n) - one(U)
end

# Shift the low-bit mask into position, with the same wrapping as left_shift.
@inline function bitmask(::Type{U}, n::Integer, offset::Integer) where {U <: Unsigned}
    return left_shift(bitmask(U, n), offset)
end

# Test a zero-based bit position, with the same wrapping as right_shift.
@inline testbit(x::Integer, i::Integer) = isodd(right_shift(x, i))

# Clear the lowest set bit, leaving zero unchanged.
@inline clearlowest(x::Unsigned) = x & (x - one(x))

"""
    pop(collection::Union{USet, UVec}) -> (new_collection, item)

Create a new collection of the same type as the input, but with the last element
removed. The new collection and the removed element are returned as a tuple.

If the collection is empty, throw an `ArgumentError`. The check can be disabled locally
with `@inbounds`, similar to `BoundsError`s.

See also: [`popfirst`](@ref), [`push`](@ref), [`deleteat`](@ref)

# Examples
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
    popfirst(collection::Union{USet, UVec}) -> (new_collection, item)

Create a new collection of the same type as the input, but with the first element
removed. The new collection and the removed element are returned as a tuple.

If the collection is empty, throw an `ArgumentError`. The check can be disabled locally
with `@inbounds`, similar to `BoundsError`s.

See also: [`pop`](@ref), [`push`](@ref), [`deleteat`](@ref)

# Examples
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

export USet,
    UVec,
    push,
    pushfirst,
    pop,
    popfirst,
    deleteat,
    setindex,
    append,
    insert,
    spliceinto,
    capacity,
    to_bits,
    from_bits,
    can_contain

end # module
