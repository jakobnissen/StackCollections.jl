module StackCollections

# By masking the shift, these function suppress the branches when the shift is
# >= bitwidth(x).
@inline function left_shift(x::Integer, u::Unsigned)
    return x << rem(u, bitwidth(x) % UInt32)
end

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

"""
    pop(collection::Union{Uset, UVec}) -> (new_collection, item)

Create a new collection of the same type as the input, but with the last element
removed. The new collection and the removed element is returned as a tuple.
If collection is empty, throw an `ArgumentError`.

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
If collection is empty, throw an `ArgumentError`.

```jldoctest
julia> (v2, element) = popfirst(UVec{UInt16}([1, 0]));

julia> element
true
=== false
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
    append,
    delete,
    capacity

end # module
