"""
    UVec{U <: Unsigned} <: AbstractVector{Bool}

Immutable boolean vector backed by a single `U`.
A `T <: UVec` has a maximum length determined by `U`, which
can be queried by `capacity(T)`.

Operations that exceed the maximum capacity, or require a nonempty vector
when given an empty one, throw an `ArgumentError`. Invalid indices throw a
`BoundsError`. These checks can be disabled locally with `@inbounds`; the
caller must ensure the operation is valid. Element conversions remain checked.
Check elision is not guaranteed for iterable construction, `append`, or variadic
`push`, whose loops use the compiler's normal inlining heuristics.

Mutable operations are not supported; use `push` `pop` and `delete`
instead of the corresponding mutable Base operations.
"""
struct UVec{U <: Unsigned} <: AbstractVector{Bool}
    # Bottom length_bits(T) encode the length.
    # The following length(x) bits, LSB-to-MSB contains vector itself
    # Remaining bits are always zero
    x::U

    global function new_uvec(u::U) where {U}
        return new{U}(u)
    end
end

UVec{U}() where {U <: Unsigned} = new_uvec(zero(U))

function UVec{U}(itr) where {U <: Unsigned}
    max_capacity = capacity(UVec{U})
    shift = length_bits(UVec{U}) % UInt32
    u = zero(U)
    n_items = 0
    for item in itr
        element = convert(Bool, item)::Bool
        n_items += 1
        @boundscheck n_items > max_capacity && throw_full_uvec()
        u |= left_shift(element % U, shift)
        shift += one(shift)
    end
    return new_uvec(u | n_items % U)
end

function unused_bits(x::UVec{U}) where {U}
    return bitwidth(U) - length_bits(UVec{U}) - length(x)
end

@noinline throw_full_uvec() = throw(ArgumentError("UVec at maximum size"))
@noinline throw_empty_uvec() = throw(ArgumentError("UVec empty"))

# This computes the lowest number of bits needed to store the length.
# It should compute entirely at compile time, and at the time of writing
# is inferred as having total effects.
@inline function length_bits(::Type{T}) where {U, T <: UVec{U}}
    total_bits = bitwidth(U)::Int
    candidate = bitwidth(Int) - leading_zeros(total_bits) - 1
    needs_more = left_shift(1, candidate % UInt32) - 1 < total_bits - candidate
    return candidate + needs_more
end

"""
    capacity(::Type{<:UVec{U}})::Int

Compute the maximum number of elements a `UVec{U}` can contain.
This computation is compile time constant.

```jldoctest
julia> capacity(UVec{UInt8})
5

julia> capacity(UVec{UInt32})
27
```
"""
capacity(::Type{T}) where {U <: Unsigned, T <: UVec{U}} = bitwidth(U) - length_bits(T)

@inline function length_mask(::Type{T}) where {U, T <: UVec{U}}
    return left_shift(one(U), length_bits(T) % UInt) - one(U)
end

Base.size(x::UVec) = (length(x),)
Base.length(x::UVec) = (x.x & length_mask(typeof(x))) % Int
Base.isempty(x::UVec) = iszero(x.x)

function inbounds_shift(::Type{T}, i::Int) where {T <: UVec}
    return (i - 1 + length_bits(T)) % UInt32
end

@inline function Base.getindex(x::UVec, i::Integer)
    @boundscheck Base.checkbounds(x, i)
    i = (i % Int)::Int
    return isodd(right_shift(x.x, inbounds_shift(typeof(x), i)))
end

"""
    push(v::UVec{U}, i)::UVec{U}

Convert `i` to `Bool`, and return a new `UVec{U}` identical to `v` but
with the converted `i` appended to the end.

Throw an `ArgumentError` if `v` is already at maximum capacity.
The check can be disabled locally with `@inbounds`, similar to `BoundsError`s.
"""
@inline function push(x::T, i) where {U <: Unsigned, T <: UVec{U}}
    b = convert(Bool, i)::Bool
    L = length(x)
    @boundscheck(L == capacity(T) && throw_full_uvec())
    u = x.x | left_shift(b % U, inbounds_shift(T, L + 1))
    return new_uvec(u + one(u))
end

function push(x::T, i, is...) where {U <: Unsigned, T <: UVec{U}}
    y = push(x, i)
    for ii in is
        y = push(y, ii)
    end
    return y
end

"""
    pushfirst(v::UVec{U}, i)::UVec{U}

Convert `i` to `Bool`, then return a new `UVec{U}` with the content of `v`,
but with the converted `i` at index 1, and all preexisting elements shifted
back.
Throw an `ArgumentError` if `v` is already at max capacity.
The check can be disabled locally with `@inbounds`, similar to `BoundsError`s.

```jldoctest
julia> v = UVec{UInt8}([1, 0, 1, 1]);

julia> v2 = pushfirst(v, true); v2 == [1, 1, 0, 1, 1]
true

julia> v == v2
false

julia> pushfirst(v2, false)
ERROR: ArgumentError: UVec at maximum size
[...]
```
"""
@inline function pushfirst(x::T, i) where {U <: Unsigned, T <: UVec{U}}
    b = convert(Bool, i)::Bool
    mask = length_mask(T)
    L = (x.x & mask) + one(U)
    @boundscheck ((L % Int) > capacity(T) && throw_full_uvec())
    u = (x.x & ~mask) << 1
    u |= left_shift(b % U, length_bits(T) % UInt32)
    return new_uvec(u | L)
end

"""
    append(v::UVec{U}, itr)::UVec{U}

Convert each element of `itr` to `Bool`,
and push them, in order, to a new copy of `v`, which is returned.

```jldoctest
julia> v = UVec{UInt16}([1, 0]);

julia> v2 = append(v, (i for i in [1, 0, 0, 1]));

julia> v2 == v
false

julia> v2 === UVec{UInt16}([1, 0, 1, 0, 0, 1])
true
```
"""
function append(v::UVec{U}, itr) where {U}
    L = length(v)
    LB = length_bits(UVec{U})
    shift = (LB + L) % UInt
    W = bitwidth(U) % UInt32
    u = v.x & ~length_mask(UVec{U})
    for i in itr
        @boundscheck shift == W && throw_full_uvec()
        iT = convert(Bool, i)::Bool
        u |= left_shift(iT % U, shift)
        L += 1
        shift += one(shift)
    end
    return new_uvec(u | (L % U))
end

@inline function pop(x::T) where {U <: Unsigned, T <: UVec{U}}
    @boundscheck(isempty(x) && throw_empty_uvec())
    L = length(x)
    shift = inbounds_shift(T, L)
    mask = ~left_shift(one(U), shift)
    element = isodd(right_shift(x.x, inbounds_shift(T, L)))
    return (new_uvec((x.x & mask) - one(U)), element)
end

@inline function popfirst(x::T) where {U <: Unsigned, T <: UVec{U}}
    @boundscheck(isempty(x) && throw_empty_uvec())
    mask = length_mask(T)
    # Get first element
    element = isodd(right_shift(x.x, length_bits(T) % UInt))
    # Extract out length
    new_len = (x.x & mask) - one(U)
    # Shift down to pop out first element, and make sure to remove
    # the bit that shifted into the length section of the integer
    u = (x.x >> 1) & ~mask
    # Add the length back
    return (new_uvec(u | new_len), element)
end

function Base.sum(x::UVec)
    T = typeof(x)
    return count_ones(x.x & ~length_mask(T))
end

function Base.reverse(x::UVec)
    T = typeof(x)
    mask = length_mask(T)
    len = x.x & mask
    # Remove length, then reverse
    u = bitreverse(x.x & ~mask)
    # We now have the bits reversed, but in the wrong position.
    shift = unused_bits(x) - length_bits(T)
    # Note: The algorithm requires that this shift can be negative;
    # hence, we do not use right_shift
    u >>= shift
    return new_uvec(u | len)
end

@inline function Base.setindex(x::UVec{U}, v, i::Integer) where {U}
    vT = convert(Bool, v)::Bool
    @boundscheck Base.checkbounds(x, i)
    i = (i % Int)::Int
    shift = inbounds_shift(typeof(x), i)
    u = x.x & ~left_shift(one(U), shift)
    u |= left_shift(vT % U, shift)
    return new_uvec(u)
end

function Base.circshift(x::UVec{U}, i::Integer) where {U <: Unsigned}
    L = length(x) % UInt
    # Exit branch on iszero(L) both for correctness, and to let compiler
    # know that L > 0 for the following mod call to optimize away the DomainError
    iszero(L) && return x
    i = (mod(i, L) % UInt)::UInt
    iszero(i) && return x

    # Now we know the shift is inbounds
    # Remove length
    u = x.x & ~length_mask(UVec{U})

    # Shift all bits upwards i bits
    result = left_shift(u, i)

    # The top i bits wrap around. We emulate wrapping by shifting them
    # L - i bits down
    result |= right_shift(x.x, (L - i) % UInt)

    # Above shifting moved some bits beyond the coding bits
    # so remove those
    coding_mask = left_shift(one(U), L % UInt) - one(U)
    coding_mask = left_shift(coding_mask, length_bits(UVec{U}) % UInt)
    result &= coding_mask

    # Now add length back in and return
    result |= L % U
    return new_uvec(result)
end
