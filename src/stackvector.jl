"""
    StackVector([itr])

Construct a `StackVector` containing up to 64 `Bool` values.
A `StackVector` is stored as an integer in memory and is immutable.
"""
struct StackVector <: AbstractVector{Bool}
    x::UInt
    len::Int

    function StackVector(x::UInt, len::Int, ::Unsafe)
        new(x, len)
    end
end

function StackVector(x::UInt, len::Int)
    (len % UInt) > Sys.WORD_SIZE && throw(DomainError(len, "len must be 0:$(Sys.WORD_SIZE)"))
    return StackVector(x & mask(len), len, unsafe)
end

mask(L) = ifelse(L == 64, typemax(UInt), UInt(1) << (L & 63) - 1)
Base.size(s::StackVector) = (length(s),)
Base.length(s::StackVector) = s.len

function Base.hash(x::StackVector, h::UInt)
    base = (0x93774c8a392b33bb % UInt) * length(x)
    return hash(x.x, h ⊻ base)
end

StackVector() = StackVector(UInt(0), 0, unsafe)

@noinline function throw_stackvec_err()
    throw(DomainError("StackVector can only contain $(Sys.WORD_SIZE) elements"))
end

function StackVector(itr)
    bits = zero(UInt)
    len = 0
    for i in itr
        len += 1
        len > Sys.WORD_SIZE && throw_stackvec_err()
        val = convert(UInt, convert(Bool, i))
        bits |= (val << ((len-1) & 63))
    end
    return StackVector(bits, len, unsafe)
end

function Base.getindex(s::StackVector, i::Int)
    @boundscheck checkbounds(s, i)
    return isodd(s.x >>> unsigned(i-1))
end

"""
    setindex(collection, v, i::Int)

Return a copy of `collection` with the value at index `i` set to `v`.

# Examples

```jldoctest
julia> x = StackVector([true, false])
2-element StackVector:
 1
 0

julia> setindex(x, false, 1)
2-element StackVector:
 0
 0
```
"""
function setindex(s::StackVector, v::Bool, i::Int)
    @boundscheck checkbounds(s, i)
    u = UInt(1) << ((i-1) & 63)
    typeof(s)(ifelse(v, s.x | u, s.x & ~u), s.len, unsafe)
end

function push(s::StackVector, v::Bool, ::Unsafe)
    return StackVector(s.x | UInt(v) << (length(s) & 63), length(s)+1, unsafe)
end

function push(s::StackVector, v)
    length(s) == 64 && throw_stackvec_err()
    v_ = convert(Bool, v)
    return push(s, v_, unsafe)
end

function pop(s::StackVector, ::Unsafe)
    return StackVector(s.x & ~(UInt(1) << (length(s) & 63)), length(s) - 1, unsafe)
end

pop(s::StackVector) = isempty(s) ? throw_empty_err() : pop(s, unsafe)

function Base.iterate(s::StackVector, i::Int=0)
    i+1 > length(s) && return nothing
    isodd(s.x >>> (i&63)), i+1
end

Base.in(v::Bool, s::StackVector) = !iszero(ifelse(v, s.x, s.x ⊻ mask(length(s))))

Base.maximum(s::StackVector) = !minimum(~s)
function Base.minimum(s::StackVector)
    isempty(s) && throw_empty_err()
    return s.x == mask(length(s))
end

Base.sum(s::StackVector) = count_ones(s.x)

function Base.convert(::Type{BitVector}, s::StackVector)
    b = BitVector(undef, length(s))
    !isempty(s) && @inbounds b.chunks[1] = s.x
    b
end

Base.:~(s::StackVector) = StackVector(s.x ⊻ mask(length(s)), s.len, unsafe)

function Base.findfirst(s::StackVector)
    isempty(s) && return nothing
    i = trailing_zeros(s.x) + 1
    i > length(s) && return nothing
    return i
end

function Base.findfirst(f::Function, s::StackVector)
    isempty(s) && return nothing
    ft::Bool = f(true)
    ff::Bool = f(false)
    ft & ff && return 1
    !(ft | ff) && return nothing
    return findfirst(ifelse(ft, s, ~s))
end

Base.argmin(s::StackVector) = argmax(~s)
function Base.argmax(s::StackVector)
    isempty(s) && throw_empty_err()
    f = findfirst(s)
    return f === nothing ? 1 : f
end

function Base.reverse(s::StackVector)
    x = s.x
    x = ((x & 0xaaaaaaaaaaaaaaaa) >>> 1)  | ((x & 0x5555555555555555) << 1)
    x = ((x & 0xcccccccccccccccc) >>> 2)  | ((x & 0x3333333333333333) << 2)
    x = ((x & 0xf0f0f0f0f0f0f0f0) >>> 4)  | ((x & 0x0f0f0f0f0f0f0f0f) << 4)
    x = bswap(x)
    x >>>= sizeof(UInt) << 3 - length(s)
    typeof(s)(x, s.len, unsafe)
end

function Base.circshift(s::StackVector, k::Int)
    isempty(s) && return s
    shift = k % length(s)
    left = ifelse(k < 0, length(s)+shift, shift) & 63
    right = (length(s) - left) & 63
    bits = ((s.x << left) | (s.x >>> right)) & mask(length(s))
    return StackVector(bits, length(s), unsafe)
end
