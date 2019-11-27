struct StackVector{L} <: AbstractVector{Bool}
    x::UInt

    function StackVector{L}(x::UInt, ::Unsafe) where L
        L isa Int || throw(TypeError(:StackVector, "", Int, typeof(L)))
        ((L ≤ Sys.WORD_SIZE) & (L > -1)) || throw(DomainError(M, "L must be 0:$(Sys.WORD_SIZE)"))
        new(x)
    end
end

mask(L) = UInt(1) << L - 1
Base.size(s::StackVector) = (length(s),)
Base.length(s::StackVector{L}) where L = L

StackVector{L}() where L = StackVector{L}(UInt(0), unsafe)
StackVector() = StackVector{Sys.WORD_SIZE}()

function Base.getindex(s::StackVector, i::Int)
    @boundscheck checkbounds(s, i)
    return (s.x >>> unsigned(i-1)) & 1 == 1
end

function setindex(s::StackVector, v::Bool, i::Int)
    @boundscheck checkbounds(s, i)
    u = 1 << unsigned(i-1)
    typeof(s)(ifelse(v, s.x | u, s.x & ~u), unsafe)
end

function Base.iterate(s::StackVector, i::Int=1)
    i > length(s) && return nothing
    @inbounds (s[i], i+1)
end

Base.in(v::Bool, s::StackVector{L}) where L = !iszero(ifelse(v, s.x, s.x ⊻ mask(L)))

Base.isempty(s::StackVector{L}) where L = iszero(L)

function Base.minimum(s::StackVector{L}) where L
    isempty(s) && throw(ArgumentError("cannot take minimum of empty collection"))
    ifelse(s.x == mask(L), true, false)
end

function Base.maximum(s::StackVector{L}) where L
    isempty(s) && throw(ArgumentError("cannot take maximum of empty collection"))
    ifelse(iszero(s.x), false, true)
end

Base.sum(s::StackVector) = count_ones(s.x)

function Base.convert(::Type{BitVector}, s::StackVector)
    b = trues(length(s))
    !isempty(s) && @inbounds b.chunks[1] = s.x
    b
end

Base.:!(s::StackVector) = typeof(s)(s.x ⊻ mask, unsafe)

function Base.filter(f::Function, s::StackVector{L}) where L
    ft::Bool = f(true)
    ff::Bool = f(false)
    ft & ff && return typeof(s)(mask(L), unsafe)
    !(ft | ff) && return typeof(s)(zero(UInt), unsafe)
    ff && return !s
    return s
end

# Need to test this TODO
function Base.reverse(s::StackVector)
    x = s.x
    x = ((x & 0xaaaaaaaaaaaaaaaa) >>> 1)  | ((x & 0x5555555555555555) << 1)
    x = ((x & 0xcccccccccccccccc) >>> 2)  | ((x & 0x3333333333333333) << 2)
    x = ((x & 0xf0f0f0f0f0f0f0f0) >>> 4)  | ((x & 0x0f0f0f0f0f0f0f0f) << 4)
    x = ((x & 0xff00ff00ff00ff00) >>> 8)  | ((x & 0x00ff00ff00ff00ff) << 8)
    x = ((x & 0xffff0000ffff0000) >>> 16) | ((x & 0x0000ffff0000ffff) << 16)
    x = ((x & 0xffffffff00000000) >>> 32) | ((x & 0x00000000ffffffff) << 32)
    x >>>= sizeof(UInt) << 3 - length(s)
    typeof(s)(x, unsafe)
end

# 1 rotate k right, & with mask, save as x
# rotate 64-L+k right, & with ((1<<k-1) << (L-k)), save as y
# result is y | x
# alternatively, use naive rot
#Base.circshift(s::StackVector)
