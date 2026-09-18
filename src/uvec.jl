"""
    UVec{U <: Unsigned} <: AbstractVector{Bool}

Immutable boolean vector backed by a single `U`.
A `T <: UVec` has a maximum length determined by `U`, which
can be queried by `capacity(T)`.

Operations that exceed the maximum capacity, or require a nonempty vector
when given an empty one, throw an `ArgumentError`. Invalid indices throw a
`BoundsError`. These checks may sometimes be disabled locally with `@inbounds`

Mutable operations are not supported; use `push`, `pushfirst`, `pop`, `popfirst`,
`deleteat`, and `Base.setindex`
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
    shift = length_bits(UVec{U})
    u = zero(U)
    n_items = 0
    for item in itr
        element = convert(Bool, item)::Bool
        n_items += 1
        @boundscheck n_items > max_capacity && throw_full_uvec()
        u |= left_shift(element % U, shift)
        shift += 1
    end
    return new_uvec(u | n_items % U)
end

@noinline function throw_uvec_too_big(dest::Type{UVec{D}}, source::Type{UVec{S}}) where {S, D}
    throw(ArgumentError("$(source)'s length exceeds capacity of $(dest)"))
end

@inline function UVec{T1}(x::UVec{T2}) where {T1 <: Unsigned, T2 <: Unsigned}
    L = length(x)
    @boundscheck L > capacity(UVec{T1}) && throw_uvec_too_big(UVec{T1}, UVec{T2})
    # Remove the source length before converting, then place the payload above
    # the destination length. This preserves high bits when widening.
    u = right_shift(x.x, length_bits(UVec{T2})) % T1
    u = left_shift(u, length_bits(UVec{T1}))
    return new_uvec(u | (L % T1))
end

# N.B: We only convert from UVec and not AbstractVector{Bool} in general
# because I want conversion here to be fast, as convert is called implicitly
Base.convert(::Type{UVec{U1}}, x::UVec) where {U1} = UVec{U1}(x)

UVec{U}(x::UVec{U}) where {U <: Unsigned} = x

function unused_bits(x::UVec{U}) where {U}
    return bitwidth(U) - length_bits(UVec{U}) - length(x)
end
maximum
@noinline throw_full_uvec() = throw(ArgumentError("UVec at maximum size"))
@noinline throw_empty_uvec() = throw(ArgumentError("UVec empty"))

# This computes the lowest number of bits needed to store the length.
# It should compute entirely at compile time, and at the time of writing
# is inferred as having total effects.
@inline function length_bits(::Type{T}) where {U, T <: UVec{U}}
    total_bits = bitwidth(U)::Int
    candidate = highestbit(total_bits)
    needs_more = bitmask(UInt, candidate) < total_bits - candidate
    return candidate + needs_more
end

"""
    capacity(::Type{<:UVec{U}})::Int

Compute the maximum number of elements a `UVec{U}` can contain.
This computation is compile time constant.

# Examples
```jldoctest
julia> capacity(UVec{UInt8})
5

julia> capacity(UVec{UInt32})
27
```
"""
capacity(::Type{T}) where {U <: Unsigned, T <: UVec{U}} = bitwidth(U) - length_bits(T)

@inline function length_mask(::Type{T}) where {U, T <: UVec{U}}
    return bitmask(U, length_bits(T))
end

Base.size(x::UVec) = (length(x),)
Base.length(x::UVec) = (x.x & length_mask(typeof(x))) % Int
Base.isempty(x::UVec) = iszero(x.x)
Base.copy(x::UVec) = x
Base.empty(::UVec{U}) where {U} = UVec{U}()
Base.IndexStyle(::Type{<:UVec}) = Base.IndexLinear()
Base.similar(x::UVec) = BitVector(x)

function inbounds_shift(::Type{T}, i::Int) where {T <: UVec}
    return i - 1 + length_bits(T)
end

@inline function Base.getindex(x::UVec, i::Integer)
    @boundscheck Base.checkbounds(x, i)
    i = (i % Int)::Int
    return testbit(x.x, inbounds_shift(typeof(x), i))
end

function Base.getindex(v::UVec{U}, idx::UnitRange{<:Integer}) where {U <: Unsigned}
    isempty(idx) && return UVec{U}()
    @boundscheck checkbounds(v, idx)
    fst, lst = first(idx) % Int, last(idx) % Int
    # Shift down to remove the first 1:(fst-1) elements
    u = right_shift(v.x, fst - 1)
    # Mask away bits after lst, and also bits we just shifted into
    # the length region
    L = lst - fst + 1
    # Mask of L payload bits above the length region
    mask = bitmask(U, L, length_bits(UVec{U}))
    return new_uvec((u & mask) | (L % U))
end

Base.getindex(v::UVec, ::Colon) = v

"""
    push(v::UVec{U}, i1, is...)::UVec{U}

Convert every element of `(i1, is...)` to `Bool`, then return a new `UVec{U}`
based on `v`, but with the converted elements, in order, appended to the end.

Throw an `ArgumentError` if `v` is already at maximum capacity.
The check can be disabled locally with `@inbounds`, similar to `BoundsError`s.

# See also: [`pop`](@ref), [`pushfirst`](@ref)

# Examples
```jldoctest
julia> v = UVec{UInt32}([1, 1, 0, 1, 0]);

julia> push(v, 0x01) == [1, 1, 0, 1, 0, 1]
true

julia> push(v, 0x01, 0, true) == [1, 1, 0, 1, 0, 1, 0, 1]
true
```
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
    pushfirst(v::UVec{U}, i1, is...)::UVec{U}

Convert every element of `(i1, is...)` to `Bool`, then return a new `UVec{U}`
with the content of `v`, but with the converted elements in order, at the beginning,
and all preexisting elements shifted back.
Throw an `ArgumentError` if `v` is already at max capacity.
The check can be disabled locally with `@inbounds`, similar to `BoundsError`s.

See also: [`push`](@ref)

# Examples
```jldoctest
julia> v = UVec{UInt8}([1, 0, 1, 1]);

julia> v2 = pushfirst(v, true); v2 == [1, 1, 0, 1, 1]
true

julia> v == v2
false

julia> pushfirst(UVec{UInt16}(v), true, true, false) == [1, 1, 0, 1, 0, 1, 1]
true

julia> pushfirst(v2, false)
ERROR: ArgumentError: UVec at maximum size
[...]
```
"""
function pushfirst(x::T, i) where {U <: Unsigned, T <: UVec{U}}
    b = convert(Bool, i)::Bool
    mask = length_mask(T)
    L = (x.x & mask) + one(U)
    @boundscheck ((L % Int) > capacity(T) && throw_full_uvec())
    u = (x.x & ~mask) << 1
    u |= left_shift(b % U, length_bits(T))
    return new_uvec(u | L)
end

function pushfirst(x::T, i1, is...) where {U <: Unsigned, T <: UVec{U}}
    n = length(is) + 1
    @boundscheck (n + length(x) > capacity(T) && throw_full_uvec())
    mask = length_mask(T)

    # Obtain updated length
    L = (x.x & mask) + (n % U)

    # Remove length field and shift existing elements upwards
    u = (x.x & ~mask) << n # n.b. n is compile time known

    # Make a U which stores the new elements in the right position
    u2 = zero(u)
    shift = length_bits(T)
    for i in (i1, is...)
        u2 |= left_shift((convert(Bool, i)::Bool) % U, shift)
        shift += 1
    end
    # Finally, create the uvec by ORing the old elements, new elements and length together.
    return new_uvec(u | u2 | L)
end

"""
    append(v::UVec{U}, itr)::UVec{U}

Convert each element of `itr` to `Bool`,
and push them, in order, to a new copy of `v`, which is returned.

See also: [`push`](@ref), [`insert`](@ref)

# Examples
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
    shift = LB + L
    W = bitwidth(U)
    u = v.x & ~length_mask(UVec{U})
    for i in itr
        @boundscheck shift == W && throw_full_uvec()
        iT = convert(Bool, i)::Bool
        u |= left_shift(iT % U, shift)
        L += 1
        shift += 1
    end
    return new_uvec(u | (L % U))
end

"""
    insert(v::UVec{U}, idx::Integer, item)::UVec{U}

Convert `item` to `Bool`, then return a new `UVec{U}` based on `v`, but with the converted
`item` inserted at index `idx`.
The elements at, or after `idx` is shifted one index up.
The index `idx` must be in `1:length(v)+1`. Throws a `BoundsError` if `idx` is out of bounds.
Throw an `ArgumentError` if `v` is at capacity. Both are disabled with `@inbounds`.

See also: [`push`](@ref), [`deleteat`](@ref), [`append`](@ref)

# Examples
```jldoctest
julia> v = UVec{UInt8}([1, 1, 0, 1]);

julia> insert(v, 2, 0) |> print
Bool[1, 0, 1, 0, 1]

julia> insert(v, 5, 1) |> print
Bool[1, 1, 0, 1, 1]

julia> insert(v, 6, 1) |> print
ERROR: BoundsError: attempt to access 4-element UVec{UInt8} at index [6]
[...]
```
"""
function insert(v::T, index::Integer, item) where {U <: Unsigned, T <: UVec{U}}
    @boundscheck if index < 0x01 || index > (length(v) + 1)
        throw(BoundsError(v, index))
    end
    @boundscheck (length(v) == capacity(T) && throw_full_uvec())
    iT = convert(Bool, item)::Bool
    # We know index is inbounds, so we truncate without checking
    idx = (index % Int)::Int
    shift = inbounds_shift(T, idx)
    mask = bitmask(U, shift)
    # Moved elements: Every element at or after index and shift it upwards
    u1 = (v.x & ~mask) << 1
    # Unmoved elements: All elements before index are not moved. Length is updated
    u2 = (v.x & mask) + one(U)
    # Finally, element is added
    u3 = left_shift(iT % U, shift)
    return new_uvec(u1 | u2 | u3)
end

"""
    deleteat(v::UVec{U}, idx::Integer)::UVec{U}
    deleteat(v::UVec{U}, idx::UnitRange{<:Integer})::UVec{U}

Return a new `UVec` based on `v`, but with the index or indices `idx` removed,
and all subsequent element shifted downwards to fill the deleted elements.

Throw a `BoundsError` if `idx` is out of bounds for `v`. This can be disabled with `@inbounds`.

See also: [`pop`](@ref), [`popfirst`](@ref), [`insert`](@ref)

# Examples
```jldoctest
julia> v = UVec{UInt8}([1, 1, 0, 1]);

julia> deleteat(v, 2:3) |> print
Bool[1, 1]

julia> deleteat(v, 4) |> print
Bool[1, 1, 0]

julia> deleteat(v, 4:5) |> print
ERROR: BoundsError: attempt to access 4-element UVec{UInt8} at index [4:5]
[...]
```
"""
@inline function deleteat(v::T, idx::Integer) where {U <: Unsigned, T <: UVec{U}}
    @boundscheck checkbounds(v, idx)
    i = (idx % Int)::Int
    shift = inbounds_shift(T, i)
    # Get a U with length decremented by one, and only all elements before idx
    mask = bitmask(U, shift)
    u = (v.x & mask) - one(U)

    # Select elements after idx and shift them down into place.
    mask = ~mask << 1
    u |= (v.x & mask) >> 1

    # Now we have old elements, new elements and the updated length
    return new_uvec(u)
end

@inline function deleteat(v::T, idx::UnitRange{<:Integer}) where {U <: Unsigned, T <: UVec{U}}
    isempty(idx) && return v
    @boundscheck checkbounds(v, idx)
    (fst, lst) = (first(idx) % Int, last(idx) % Int)
    B = length_bits(T)
    L = lst - fst + 1

    # Get U with elements before fst, and updated length
    mask = bitmask(U, fst + B - 1)
    u1 = (v.x & mask) - (L % U)

    # Shift the suffix into place, then discard everything below it. Masking
    # after shifting also handles deletion through the MSB without a width-sized shift.
    u2 = right_shift(v.x, L) & ~mask

    return new_uvec(u1 | u2)
end

@inline function pop(x::T) where {U <: Unsigned, T <: UVec{U}}
    @boundscheck(isempty(x) && throw_empty_uvec())
    L = length(x)
    shift = inbounds_shift(T, L)
    mask = ~singlebit(U, shift)
    element = testbit(x.x, shift)
    return (new_uvec((x.x & mask) - one(U)), element)
end

@inline function popfirst(x::T) where {U <: Unsigned, T <: UVec{U}}
    @boundscheck(isempty(x) && throw_empty_uvec())
    mask = length_mask(T)
    # Get first element
    element = testbit(x.x, length_bits(T))
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

function Base.reverse(v::UVec{U}, start::Integer, stop::Integer) where {U}
    stop <= start && return v
    @boundscheck checkbounds(v, start:stop)
    fst, lst = (start % Int)::Int, (stop % Int)::Int

    # Extract the bits that should be reversed, and reverse them with bitreverse
    L = lst - fst + 1
    shift = length_bits(UVec{U}) + fst - 1
    mask = bitmask(U, L, shift)
    u = bitreverse(v.x & mask)

    # Reversing bits may have shifted them up or down. E.g. an integer
    # 0x00000ff0 turns into 0x0ff00000.
    # Shift back into position. Note than >> can shift in both directions,
    # depending on whether the shift is negative or positive.
    downshift = bitwidth(U) - L - 2shift
    return new_uvec((v.x & ~mask) | (u >> downshift))
end

@inline function Base.setindex(x::UVec{U}, v, i::Integer) where {U}
    @boundscheck Base.checkbounds(x, i)
    vT = convert(Bool, v)::Bool
    i = (i % Int)::Int
    shift = inbounds_shift(typeof(x), i)
    u = x.x & ~singlebit(U, shift)
    u |= left_shift(vT % U, shift)
    return new_uvec(u)
end

@noinline function throwdimmismatch(nindices::Integer, nitems::Integer)
    throw(DimensionMismatch("Tried to assign $(nitems) items to $(nindices) indices"))
end

function Base.setindex(
        v::UVec{U},
        items::AbstractVector,
        index::UnitRange{<:Integer}
    ) where {U <: Unsigned}
    @boundscheck checkbounds(v, index)
    Lt = length(items)
    Li = length(index)
    @boundscheck(Li == Lt || throwdimmismatch(Li, Lt))
    iszero(Li) && return v
    return _setindex(v, items, index, Li % Int)
end

function _setindex(
        v::UVec{U},
        items::AbstractVector,
        index::UnitRange,
        Li::Int,
    ) where {U <: Unsigned}
    # Shift is the left shift up to first bit to replace
    shift = inbounds_shift(UVec{U}, first(index) % Int)
    # Mask out all selected bits
    u = v.x & ~bitmask(U, Li, shift)
    # Fill them in manually
    for item in items
        vT = convert(Bool, item)::Bool
        u |= left_shift(vT % U, shift)
        shift += 1
    end
    return new_uvec(u)
end

function _setindex(
        v::UVec{D},
        items::UVec{S},
        index::UnitRange,
        Li::Int,
    ) where {S <: Unsigned, D <: Unsigned}
    # Shift in destination up to first bit to replace
    dshift = inbounds_shift(UVec{D}, first(index) % Int)
    # Mask out all selected bits in destination
    u = v.x & ~bitmask(D, Li, dshift)
    # Extract first Li coding bits of `items`
    payload = (items.x >> length_bits(UVec{S})) & bitmask(S, Li)
    # Shift them into place and return
    return new_uvec(u | left_shift(payload % D, dshift))
end

function Base.setindex(
        v::UVec{U},
        items,
        indices::AbstractVector{<:Integer}
    ) where {U <: Unsigned}
    @boundscheck checkbounds(v, indices)
    # Normalize Boolean masks to their selected positions without allocating
    # an index vector. Ordinary integer vectors pass through unchanged.
    indices = Base.to_index(indices)
    (nitems, nindices) = (length(items), length(indices))
    @boundscheck(nitems == nindices || throwdimmismatch(nindices, nitems))
    u = v.x
    for (item, index) in zip(items, indices)
        vT = convert(Bool, item)::Bool
        shift = inbounds_shift(UVec{U}, index % Int)
        u &= ~singlebit(U, shift)
        u |= left_shift(vT % U, shift)
    end
    return new_uvec(u)
end

Base.circshift(x::UVec, i::Tuple{Integer}) = circshift(x, only(i))
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
    result |= right_shift(x.x, L - i)

    # Above shifting moved some bits beyond the coding bits
    # so remove those
    coding_mask = bitmask(U, L, length_bits(UVec{U}))
    result &= coding_mask

    # Now add length back in and return
    result |= L % U
    return new_uvec(result)
end

@inline function Base.findnext(f::Union{typeof(identity), typeof(!)}, v::UVec{U}, idx::Integer) where {U <: Unsigned}
    # Base throws below the first index, but returns nothing past the end.
    @boundscheck(idx < 1 && Base.throw_boundserror(v, idx))
    idx > length(v) && return nothing
    idx = idx % Int
    # Remove the length and elements before idx. Complementing also sets
    # unused high bits; checking the result against the length excludes them.
    u = f === identity ? v.x : ~v.x
    u = right_shift(u, length_bits(UVec{U}) + idx - 1)
    result = trailing_zeros(u) + idx
    return result <= length(v) ? result : nothing
end

@inline function Base.findprev(f::Union{typeof(identity), typeof(!)}, v::UVec{U}, idx::Integer) where {U <: Unsigned}
    # Check both limits before narrowing potentially large integer indices.
    @boundscheck(idx > length(v) && Base.throw_boundserror(v, idx))
    idx < 1 && return nothing
    idx = idx % Int
    # Shift idx to the top, discarding all later elements. Length bits can
    # remain: a match in that field produces a nonpositive result.
    u = f === identity ? v.x : ~v.x
    u = left_shift(u, bitwidth(U) - idx - length_bits(UVec{U}))
    result = idx - leading_zeros(u)
    return result > 0 ? result : nothing
end

@inline function Base.argmin(v::UVec{U}) where {U}
    @boundscheck(isempty(v) && throw_empty_uvec())
    # Remove length bits
    u = right_shift(v.x, length_bits(UVec{U}))
    n = trailing_ones(u) # The zero padding terminates the run even when all elements are true.
    # If n == length(v), the first unset bit was in the uncoding bits,
    # so we return 1.
    return n == length(v) ? 1 : n + 1
end

@inline function Base.argmax(v::UVec{U}) where {U}
    @boundscheck(isempty(v) && throw_empty_uvec())
    # Remove length bits
    u = right_shift(v.x, length_bits(UVec{U}))
    # All coding bits are false => return 1
    iszero(u) && return 1
    # Lowest set bit
    return trailing_zeros(u) + 1
end
