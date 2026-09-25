"""
    UVec{U <: Unsigned} <: AbstractVector{Bool}

Immutable boolean vector backed by a single `U`.
A `T <: UVec` has a maximum length determined by `U`, which
can be queried by `capacity(T)`.

Construct from an iterable of elements `convert`able to `Bool`.

# Extended help
Operations that exceed the maximum capacity, or require a nonempty vector
when given an empty one, throw an `ArgumentError`. Invalid indices throw a
`BoundsError`. These checks may sometimes be disabled locally with `@inbounds`

Mutable operations are not supported; use `push`, `pushfirst`, `pop`, `popfirst`,
`deleteat`, and `setindex`
instead of the corresponding mutable Base operations.

The underlying integer of an `x::UVec` can be obtained with [`to_bits`](@ref),
and a `UVec` can be constructed from its underlying integer with
[`from_bits`](@ref).

Most operations on `UVec` that returns boolean vectors, such as `filter`,
`reverse` and indexing are specialized to return `UVec`. However, it is not
guaranteed that all methods are implemented and do not fall back to a default
implementation. However, specialized methods implemented that explicitly return `UVec`
are guaranteed to not be removed in future minor releases.
`Base.similar(::UVec, args...)` returns `BitArray`.
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

"""
    to_bits(v::UVec{U})::U

Obtain the backing integer of `v`.
The value of `v` is an implementation detail, but the following properties
are guaranteed:
* This operations can optimize to a noop
* The result is a value of type `U`
* No distinct `UVec`s map to the same integer, however the inverse
  is not guaranteed.
* For any `v::UVec`, `from_bits(UVec, to_bits(v)) === v`.

See also: [`from_bits`](@ref)
"""
to_bits(v::UVec) = v.x

"""
    from_bits(::Type{UVec}, u::U)::UVec{U} where {U <: Unsigned}

Construct an `UVec{U}` from its underlying integer.
Not all integers are valid backing storage for a `UVec`, so the
result may be a corrupted and malfunctioning `UVec`.
The only way to get a guaranteed valid input to this function is
`to_bits(::UVec)`.

This function is guaranteed to be:
* Optimizable to a noop
* Round-trippable with `to_bits`, in the sense that for any `v::UVec`,
  `from_bits(UVec, to_bits(v)) === v`.

# Examples
```
julia> v = UVec{UInt32}([0, 1, 1, 1, 0, 1, 0, 1, 0, 1]);

julia> u = to_bits(v); typeof(u)
UInt32

julia> from_bits(UVec, u) === v
true
```
"""
from_bits(::Type{UVec}, u::Unsigned) = new_uvec(u)

UVec{U}() where {U <: Unsigned} = new_uvec(zero(U))

function UVec{U}(::UndefInitializer, n::Integer) where {U <: Unsigned}
    if n < 0 || n > capacity(UVec{U})
        throw_uvec_too_big(UVec{U}, n)
    end
    return new_uvec(n % U)
end

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

@noinline throw_boundserror(v, i) = throw(BoundsError(v, i))

# Like Base, reject scalar Boolean indices, even though Bool <: Integer.
# Since Boolean vectors are masks, treating `true` as the index 1 would make
# e.g. `v[[true, true]]` and `[v[true], v[true]]` differ.
@noinline function throw_bool_index(i::Bool)
    throw(ArgumentError("invalid index: $(i) of type Bool"))
end

@noinline function throw_uvec_too_big(dest::Type{UVec{D}}, source::Type{UVec{S}}) where {S, D}
    throw(ArgumentError("$(source)'s length exceeds capacity of $(dest)"))
end

@noinline function throw_uvec_too_big(T::Type{UVec{U}}, n::Integer) where {U}
    throw(ArgumentError("Cannot create $(T) of length $(n); $(n) is not in 0:$(capacity(T))"))
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

function Base.similar(x::UVec, ::Type{Bool}, axes::NTuple{N, Int}) where {N}
    return BitArray{N}(undef, axes)
end

function inbounds_shift(::Type{T}, i::Int) where {T <: UVec}
    return i - 1 + length_bits(T)
end

Base.getindex(::UVec, i::Bool) = throw_bool_index(i)

@inline function Base.getindex(x::UVec, i::Integer)
    @boundscheck Base.checkbounds(x, i)
    i = (i % Int)::Int
    return testbit(x.x, inbounds_shift(typeof(x), i))
end

@inline function Base.getindex(v::UVec{U}, idx::UnitRange{<:Integer}) where {U <: Unsigned}
    @boundscheck checkbounds(v, idx)
    fst, lst = first(idx) % Int, last(idx) % Int
    # Shift down to remove the first 1:(fst-1) elements
    u = right_shift(v.x, fst - 1)
    # Mask away bits after lst, and also bits we just shifted into
    # the length region. An empty range gives L == 0 and thus an empty mask.
    L = lst - fst + 1
    # Mask of L payload bits above the length region
    mask = bitmask(U, L, length_bits(UVec{U}))
    return new_uvec((u & mask) | (L % U))
end

# Boolean ranges are masks, just like other Boolean vectors.
Base.@propagate_inbounds function Base.getindex(v::UVec{U}, idx::UnitRange{Bool}) where {U <: Unsigned}
    return select_mask(v, idx, false)
end

function Base.getindex(v::UVec{U}, idx::AbstractVector{<:Integer}) where {U <: Unsigned}
    L = length(idx)
    @boundscheck if L > capacity(UVec{U})
        throw_full_uvec()
    end
    shift = length_bits(UVec{U})
    u = zero(U)
    for i in idx
        b = v[i]
        u |= left_shift(b % U, shift)
        shift += 1
    end
    return new_uvec(u | (L % U))
end

Base.@propagate_inbounds function Base.getindex(v::UVec{U}, idx::AbstractVector{Bool}) where {U <: Unsigned}
    return select_mask(v, idx, false)
end

# Return the elements of `v` at the positions where `mask` is `!invert`.
Base.@propagate_inbounds function select_mask(v::UVec{U}, mask::AbstractVector{Bool}, invert::Bool) where {U <: Unsigned}
    @boundscheck checkbounds(v, mask)
    u = zero(U)
    vu = v.x

    # Only selected bits contribute to u and advance the writing position.
    # Masking the bit avoids a branch and prevents unselected true values
    # from contaminating a later selected false value.
    vushift = length_bits(UVec{U})
    ushift = vushift
    for element in mask
        selected = element ⊻ invert
        bit = right_shift(vu, vushift) & (selected % U)
        u |= left_shift(bit, ushift)
        ushift += selected % Int
        vushift += 1
    end
    return new_uvec(u | ((ushift - length_bits(UVec{U})) % U))
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

@inline function push(x::T, i, is...) where {U <: Unsigned, T <: UVec{U}}
    bs = map(b -> convert(Bool, b)::Bool, (i, is...))
    L = length(x)
    @boundscheck (length(bs) + L > capacity(T) && throw_full_uvec())
    u = x.x + length(bs) % U
    shift = inbounds_shift(T, L + 1)
    for b in bs
        u |= left_shift(b % U, shift)
        shift += 1
    end
    return new_uvec(u)
end

"""
    pushfirst(v::UVec{U}, i1, is...)::UVec{U}

Convert every element of `(i1, is...)` to `Bool`, then return a new `UVec{U}`
with the content of `v`, but with the converted elements in order, at the beginning,
and all preexisting elements shifted back.
Throw an `ArgumentError` if `v` is too big to accomodate the extra elements
(see [`capacity`](@ref))
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
@inline function pushfirst(x::T, i) where {U <: Unsigned, T <: UVec{U}}
    b = convert(Bool, i)::Bool
    mask = length_mask(T)
    L = (x.x & mask) + one(U)
    @boundscheck ((L % Int) > capacity(T) && throw_full_uvec())
    u = (x.x & ~mask) << 1
    u |= left_shift(b % U, length_bits(T))
    return new_uvec(u | L)
end

@inline function pushfirst(x::T, i1, is...) where {U <: Unsigned, T <: UVec{U}}
    bs = map(b -> convert(Bool, b)::Bool, (i1, is...))
    n = length(bs)
    @boundscheck (n + length(x) > capacity(T) && throw_full_uvec())
    mask = length_mask(T)

    # Obtain updated length
    L = (x.x & mask) + (n % U)

    # Remove length field and shift existing elements upwards
    u = (x.x & ~mask) << n # n.b. n is compile time known

    # Make a U which stores the new elements in the right position
    u2 = zero(u)
    shift = length_bits(T)
    for b in bs
        u2 |= left_shift(b % U, shift)
        shift += 1
    end
    # Finally, create the uvec by ORing the old elements, new elements and length together.
    return new_uvec(u | u2 | L)
end

"""
    append(v::UVec{U}, itr)::UVec{U}

Convert each element of `itr` to `Bool`,
and push them, in order, to a new copy of `v`, which is returned.
Throw an `ArgumentError` if the appended elements can't fit in a `UVec{U}`;
this may be suppressed with `@inbounds`.

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
Base.@propagate_inbounds function append(v::UVec{U}, itr) where {U}
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

@inline function append(v::UVec{U}, w::UVec) where {U}
    L = length(v)
    Lw = length(w)
    @boundscheck L + Lw > capacity(UVec{U}) && throw_full_uvec()
    # The total length check guarantees that w fits in UVec{U}
    payload = @inbounds(UVec{U}(w)).x >> length_bits(UVec{U})
    return new_uvec((v.x | left_shift(payload, inbounds_shift(UVec{U}, L + 1))) + Lw % U)
end

"""
    insert(v::UVec{U}, idx::Integer, item)::UVec{U}

Convert `item` to `Bool`, then return a new `UVec{U}` based on `v`, but with the converted
`item` inserted at index `idx`.
The elements at, or after `idx` is shifted one index up.
The index `idx` must be in `1:length(v)+1`. Throws a `BoundsError` if `idx` is out of bounds.
Throw an `ArgumentError` if `v` is at capacity. Both are disabled with `@inbounds`.
Throw an `ArgumentError` if `idx` is a `Bool`, even with `@inbounds`.

See also: [`spliceinto`](@ref), [`push`](@ref), [`deleteat`](@ref), [`append`](@ref)

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
insert(::UVec, index::Bool, item) = throw_bool_index(index)

@inline function insert(v::T, index::Integer, item) where {U <: Unsigned, T <: UVec{U}}
    @boundscheck if index < 0x01 || index > (length(v) + 1)
        throw_boundserror(v, index)
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
    deleteat(v::UVec{U}, mask::AbstractVector{Bool})::UVec{U}

Return a new `UVec` based on `v`, but with the index or indices `idx` removed,
and all subsequent element shifted downwards to fill the deleted elements.

If a Boolean vector `mask` is passed, including a `UnitRange{Bool}`, it is
used as a mask, and the elements at positions where `mask` is `true` are removed.

Throw a `BoundsError` if `idx` is out of bounds for `v`, or if `mask` does not
have the same length as `v`. This can be disabled with `@inbounds`.
Throw an `ArgumentError` if `idx` is a `Bool`, even with `@inbounds`.

See also: [`pop`](@ref), [`popfirst`](@ref), [`spliceinto`](@ref)

# Examples
```jldoctest
julia> v = UVec{UInt8}([1, 1, 0, 1]);

julia> deleteat(v, 2:3) |> print
Bool[1, 1]

julia> deleteat(v, 4) |> print
Bool[1, 1, 0]

julia> deleteat(v, [true, false, false, true]) |> print
Bool[1, 0]

julia> deleteat(v, 4:5) |> print
ERROR: BoundsError: attempt to access 4-element UVec{UInt8} at index [4:5]
[...]
```
"""
deleteat(::UVec, idx::Bool) = throw_bool_index(idx)

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
    # N.B: An empty range gives L == 0, in which case u1 | u2 == v.x
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

# Also resolves the ambiguity between the UnitRange{<:Integer} method above
# and the AbstractVector{Bool} method below.
@inline function deleteat(v::UVec, mask::UnitRange{Bool})
    @boundscheck checkbounds(v, mask)
    # The true elements of any Boolean range are at positions (2 - first):length
    return @inbounds deleteat(v, (2 - first(mask)):length(mask))
end

Base.@propagate_inbounds function deleteat(v::UVec, mask::AbstractVector{Bool})
    return select_mask(v, mask, true)
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

Base.count(x::UVec) = sum(x)

# Any set bit above the length region is a true element
Base.any(x::UVec) = x.x > length_mask(typeof(x))

# All coding bits are set, and the unused bits are always zero
Base.all(x::UVec{U}) where {U} = x.x >> length_bits(typeof(x)) == bitmask(U, length(x))

# Unused bits are always zero, so equal vectors have identical bits
Base.:(==)(a::UVec{U}, b::UVec{U}) where {U} = a.x == b.x

function Base.:(==)(a::UVec{U}, b::UVec) where {U}
    # If the lengths match, b fits in a UVec{U}. Else, the conversion yields
    # garbage, but that is harmless, since the result is then false anyway.
    return (length(a) == length(b)) & (a.x == @inbounds(UVec{U}(b)).x)
end

Base.isequal(a::UVec, b::UVec) = a == b

function Base.reverse(x::UVec{U}) where {U}
    T = typeof(x)
    # Remove length, then reverse. Element i is now at bit bitwidth(U) - i
    u = bitreverse(x.x >> length_bits(T))
    # Shift the last element down to bit length_bits(T). This shift is
    # always in 0:bitwidth(U)-1, and shifts only zeros into the length region.
    u = right_shift(u, unused_bits(x))
    return new_uvec(u | (x.x & length_mask(T)))
end

@inline function Base.reverse(v::UVec{U}, start::Integer, stop::Integer) where {U}
    # Like Base, do not check bounds if stop <= start, since that is a no-op
    @boundscheck if stop > start
        checkbounds(v, start:stop)
    end
    fst, lst = (start % Int)::Int, (stop % Int)::Int

    # Extract the bits that should be reversed, and reverse them with bitreverse.
    # The comparison is done before truncation, and yields an empty mask for a no-op.
    L = ifelse(stop > start, lst - fst + 1, 0)
    shift = inbounds_shift(UVec{U}, fst)
    mask = bitmask(U, L, shift)
    u = bitreverse(v.x & mask)

    # Reversing moved bits shift:shift+L-1 to W-shift-L:W-shift-1, where W is the
    # bitwidth. Shift them down to 0:L-1, then up to their original position.
    # Both shifts are in 0:W-1 when the range is in bounds.
    u = left_shift(right_shift(u, bitwidth(U) - shift - L), shift)
    return new_uvec((v.x & ~mask) | u)
end

"""
    setindex(v::UVec{U}, item, indices::Integer)::UVec{U}
    setindex(v::UVec{U}, items::AbstractVector, indices::AbstractVector{<:Integer})::UVec{U}

Return a new `UVec{U}` based on `v`, but with the elements at `indices`
set to `items`.
Each element of `items` is converted to `Bool` and assigned to the corresponding
index in `indices`. For repeated indices, the last assignment wins.

Boolean vector indices are masks: their length must match `v`, and `items` must contain
`count(indices)` items. Scalar `Bool` indices throw an `ArgumentError`, even with `@inbounds`.

Throw a `BoundsError` if any index is not an existing index of `v`.
Else, if the number of selected indices does not match the length of `items`,
a `DimensionMismatch` error is thrown.
These errors may be elided with `@inbounds`.

See also: [`push!`](@ref), [`spliceinto`](@ref)

# Examples
```jldoctest
julia> v = UVec{UInt64}([1, 1, 1, 1, 1, 1, 1, 1, 1]);

julia> v2 = setindex(v, [0, 1, 0, 1, 0], 3:7); println(v2)
Bool[1, 1, 0, 1, 0, 1, 0, 1, 1]

julia> v2 == v # v is unchanged
false

julia> setindex(v, [1, 0, 1], 2:3)
ERROR: DimensionMismatch: Tried to assign 3 items to 2 indices
[...]
```
"""
setindex(::UVec, v, i::Bool) = throw_bool_index(i)

@inline function setindex(x::UVec{U}, v, i::Integer) where {U}
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

# The elaborate dispatch here is to avoid the annoying case that we have
# V{Bool} <: V{<:Integer}, yet they have different semantics when used as
# indices. This is eventually handled by Base.to_index.
@inline function setindex(
        v::UVec{U},
        items::AbstractVector,
        index::UnitRange{<:Integer}
    ) where {U <: Unsigned}
    @boundscheck checkbounds(v, index)
    Lt = length(items)
    Li = length(index)
    @boundscheck(Li == Lt || throwdimmismatch(Li, Lt))
    # N.B: Empty ranges need no special casing, since the masks are then empty
    return _setindex(v, items, index, Li % Int)
end

Base.@propagate_inbounds function setindex(
        v::UVec{U},
        items::AbstractVector,
        indices::UnitRange{Bool},
    ) where {U <: Unsigned}
    return setindexindices(v, items, indices)
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

Base.@propagate_inbounds function setindex(
        v::UVec{U},
        items::AbstractVector,
        indices::AbstractVector{<:Integer}
    ) where {U <: Unsigned}
    return setindexindices(v, items, indices)
end

Base.@propagate_inbounds function setindexindices(v::UVec{U}, items::AbstractVector, indices::AbstractVector{<:Integer}) where {U <: Unsigned}
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
    # An empty vector is all zero bits, so any shift of it works. Using a divisor
    # of 1 for this case avoids a branch, and lets the compiler elide the zero
    # division check. A shift of zero needs no special casing either.
    i = (mod(i, max(L, one(L))) % UInt)::UInt

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
    @boundscheck(idx < 1 && throw_boundserror(v, idx))
    L = length(v)
    # Clamp before truncating, so large indices can't wrap into bounds.
    # Since result >= idx, an index past the end always returns nothing.
    i = ifelse(idx > L, L + 1, idx % Int)
    # Remove the length and elements before idx. Complementing also sets
    # unused high bits; checking the result against the length excludes them.
    u = f === identity ? v.x : ~v.x
    u = right_shift(u, length_bits(UVec{U}) + i - 1)
    result = trailing_zeros(u) + i
    return result <= L ? result : nothing
end

@inline function Base.findprev(f::Union{typeof(identity), typeof(!)}, v::UVec{U}, idx::Integer) where {U <: Unsigned}
    # Check both limits before narrowing potentially large integer indices.
    @boundscheck(idx > length(v) && throw_boundserror(v, idx))
    # Clamp before truncating, so small indices can't wrap into bounds.
    # Since result <= idx, an index before the start always returns nothing.
    i = ifelse(idx < 1, 0, idx % Int)
    # Shift idx to the top, discarding all later elements. Length bits can
    # remain: a match in that field produces a nonpositive result.
    u = f === identity ? v.x : ~v.x
    u = left_shift(u, bitwidth(U) - i - length_bits(UVec{U}))
    result = i - leading_zeros(u)
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

"""
    spliceinto(v::UVec{U}, i::Integer, e::AbstractVector)::UVec{U}

Return a copy of `v` with the elements of `e` (converted to `Bool`) inserted positions
`i:i+length(e)-1`, and the previously existing elements at `i:length(v)` 
shifted to higher indices.

Throw a `BoundsError` if `i` is not in `1:length(v)+1`.
Throw an `ArgumentError` if the resulting `UVec{U}`'s
length would exceed `capacity(UVec{U})`.
Both exceptions can be suppressed with `@inbounds`.

Boolean indices are not supported: Throw an `ArgumentError` if `i` is a `Bool`,
even with `@inbounds`.

See also: [`insert`](@ref), [`deleteat`](@ref), [`push`](@ref)

# Examples
```jldoctest
julia> v = UVec{UInt32}([0, 1, 1, 1, 1, 0, 0]);

julia> v2 = spliceinto(v, 3, [0, 0, 0]);

julia> v2 === typeof(v)([0, 1, 0, 0, 0, 1, 1, 1, 0, 0])
true

julia> spliceinto(v, 8, [1, 1]) == [0, 1, 1, 1, 1, 0, 0, 1, 1]
true
```
"""
function spliceinto(v::UVec{U}, i, e::AbstractVector) where {U <: Unsigned}
    return spliceinto(v, i, UVec{U}(e)::UVec{U})
end

spliceinto(::UVec{U}, i::Bool, ::UVec{U}) where {U <: Unsigned} = throw_bool_index(i)

# Base is inconsistent about whether Boolean ranges are masks or integers here,
# and a mask selecting no elements has no position to insert at, so reject them.
@noinline function throw_bool_splice(i::UnitRange{Bool})
    throw(ArgumentError("Boolean ranges are not supported by spliceinto, got $(i)"))
end

spliceinto(::UVec{U}, i::UnitRange{Bool}, ::UVec{U}) where {U <: Unsigned} = throw_bool_splice(i)

@inline function spliceinto(v::UVec{U}, i::Integer, e::UVec{U}) where {U <: Unsigned}
    L = length(e) + length(v)
    @boundscheck if L > capacity(UVec{U})
        throw_full_uvec()
    end
    @boundscheck if i < 1 || i > length(v) + 1
        throw_boundserror(v, i)
    end

    i = (i % Int)::Int
    LB = length_bits(UVec{U})

    # Coding bits of e in the right place
    u = left_shift(e.x >> LB, LB + i - 1)

    # Add in the bits of v that goes before e.
    # They are already in right place so we just mask out subsequent coding bits.
    mask = bitmask(U, LB + i - 1)
    u |= v.x & mask

    # Add in coding bits of v that go after e. Length bits are masked out here
    u |= left_shift(v.x & ~mask, length(e))

    # Update length. Since u contains the length of v, we add the length bits of e.
    return new_uvec(u + length(e) % U)
end

"""
    spliceinto(v::UVec{U}, i::UnitRange, e::AbstractVector)::UVec{U}

Return a copy of `v` with the indices at `i` deleted, and the  elements of `e`
(converted to `Bool`) inserted at the deletion site.
Elements in `v` after `i` are shifted to immediately after the inserted `e`.

Throw a `BoundsError` if `i` is not in `1:length(v)+1`. Throw an `ArgumentError`
if the resulting `UVec{U}`'s length would exceed `capacity(UVec{U})`.
Both exceptions can be suppressed with `@inbounds`.

Boolean indices are not supported: Throw an `ArgumentError` if `i` is a
`UnitRange{Bool}`, even with `@inbounds`.

This is equivalent to `spliceinto(deleteat(v, i), first(i), e)`, but more efficient.

See also: [`insert`](@ref), [`deleteat`](@ref), [`push`](@ref)

# Examples
```jldoctest
julia> v = UVec{UInt32}([0, 1, 1, 1, 1, 0, 0]);

julia> v2 = spliceinto(v, 3:4, [0, 0, 0]);

julia> v2 === typeof(v)([0, 1, 0, 0, 0, 1, 0, 0])
true

julia> spliceinto(v, 2:6, [1, 1]) == [0, 1, 1, 0]
true
```
"""
@inline function spliceinto(v::UVec{U}, i::UnitRange, e::UVec{U}) where {U <: Unsigned}
    # We can't forward to just checking if i is inbounds in v, because that trivially
    # returns true for empty i, whereas we care about the _location_ of the range.
    @boundscheck if first(i) < 1 || last(i) > length(v)
        throw_boundserror(v, i)
    end

    # Since we now checked i is inbounds, we can truncate to Int without checks
    fst, lst = (first(i) % Int)::Int, (last(i) % Int)::Int
    L = lst - fst + 1
    @boundscheck if length(v) + length(e) - L > capacity(UVec{U})
        throw_full_uvec()
    end

    Le = length(e)
    # Offset of the first deleted bit
    shift = inbounds_shift(UVec{U}, fst)
    mask = bitmask(U, shift)

    # Bits of v at indices 1:fst-1, kept in place, including the length
    u = v.x & mask

    # Bits of v at indices lst+1:length(v), shifted down to fst, then up past e.
    # If shift == bitwidth(U), the mask wraps to zero. This is still correct,
    # since this can only happen when nothing is deleted or inserted.
    u |= left_shift(right_shift(v.x, L) & ~mask, Le)

    # Bits of e shifted into fst:fst+length(e)-1
    u |= left_shift(e.x >> length_bits(UVec{U}), shift)

    # Update length. Since u contains the length of v, we add the difference.
    return new_uvec(u + (Le - L) % U)
end
