struct UVec{U <: Unsigned} <: AbstractVector{Bool}
    # For a B bits integer, the bottom ceil(log2(B)) encode the length.
    # The length(x) from LSB to MSB encode the content
    # Unused top bits are always zero
    x::U

    global function new_uvec(u::U) where {U}
        return new{U}(u)
    end
end

UVec{U}() where {U <: Unsigned} = new_uvec(zero(U))

function UVec{U}(itr) where {U <: Unsigned}
    max_capacity = coding_bits(UVec{U})
    shift = length_bits(UVec{U}) % UInt32
    u = zero(U)
    n_items = 0
    for item in itr
        element = convert(Bool, item)::Bool
        n_items += 1
        n_items > max_capacity && throw_full_uvec()
        u |= left_shift(element % U, shift)
        shift += one(shift)
    end
    return new_uvec(u | n_items % U)
end

function unused_bits(x::UVec{U}) where {U}
    T = typeof(x)
    return bitwidth(U) - length_bits(T) - length(x)
end

@noinline throw_full_uvec() = throw(ArgumentError("UVec at maximum size"))
@noinline throw_empty_uvec() = throw(ArgumentError("UVec empty"))


@inline function length_bits(::Type{T}) where {U, T <: UVec{U}}
    lz = leading_zeros(Int(bitwidth(U)))
    # Subtract one because the length bits themselves take up some room
    return bitwidth(Int) - lz - 1
end

coding_bits(::Type{T}) where {U <: Unsigned, T <: UVec{U}} = bitwidth(U) - length_bits(T)

@inline function length_mask(::Type{T}) where {U, T <: UVec{U}}
    return left_shift(one(U), length_bits(T) % UInt) - one(U)
end

Base.size(x::UVec) = (length(x),)
Base.length(x::UVec) = (x.x & length_mask(typeof(x))) % Int
Base.isempty(x::UVec) = iszero(x.x)

function inbounds_shift(::Type{T}, i::Int) where {T <: UVec}
    return (i - 1 + length_bits(T)) % UInt32
end

function Base.getindex(x::UVec, i::Integer)
    checkbounds(x, i)
    i = (i % Int)::Int
    return isodd(right_shift(x.x, inbounds_shift(typeof(x), i)))
end

function push(x::T, i) where {U <: Unsigned, T <: UVec{U}}
    b = convert(Bool, i)::Bool
    L = length(x)
    L == coding_bits(T) && throw_full_uvec()
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

function pop(x::T) where {U <: Unsigned, T <: UVec{U}}
    isempty(x) && throw_empty_uvec()
    L = length(x)
    shift = inbounds_shift(T, L)
    mask = ~left_shift(one(U), shift)
    element = isodd(right_shift(x.x, inbounds_shift(T, L)))
    return (new_uvec((x.x & mask) - one(U)), element)
end

function Base.sum(x::UVec)
    T = typeof(x)
    return count_ones(x.x & ~length_mask(T))
end

function Base.reverse(x::UVec)
    T = typeof(x)
    mask = length_mask(T)
    len = x.x & mask
    u = bitreverse(x.x & ~mask)
    shift = unused_bits(x) - length_bits(T)
    # Note: The algorithm requires that this shift can be negative;
    # hence, we do not use right_shift
    u >>= shift
    return new_uvec(u | len)
end

function Base.setindex(x::UVec{U}, v, i::Integer) where {U}
    vT = convert(Bool, v)::Bool
    checkbounds_lightboundserror(x, i)
    i = i % Int
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
