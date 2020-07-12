"""
    OneHotVector([itr])

Constuct a `OneHotVector`, an `AbstractVector{Bool}` containing exactly one
`true`, and all other values `false`.
The vector is stored in memory as two integers and is immutable.
"""
struct OneHotVector <: AbstractVector{Bool}
    len::Int
    index::Int

    OneHotVector(len::Int, index::Int, ::Unsafe) = new(len, index)
end

function OneHotVector(len::Integer, index::Integer)
    lenT = convert(Int, len)
    indT = convert(Int, index)
    lenT < 1 && throw(ArgumentError("Length must be at least one"))
    in(indT, Base.OneTo(lenT)) || throw(ArgumentError("Index must be in 1:len"))
    return OneHotVector(lenT, indT, unsafe)
end

@noinline notrue() = throw(ArgumentError("No trues in vector"))
@noinline twotrue() = throw(ArgumentError("More than one true in argument"))

function OneHotVector(v)
    index = 0
    length = 0
    for elem in v
        length += 1
        b = convert(Bool, elem)
        b & (index != 0) && twotrue()
        b && (index = length)
    end
    index == 0 && notrue()
    return OneHotVector(length, index, unsafe)
end

function Base.hash(x::OneHotVector, h::UInt)
    base = 0x2c6ed6da44a96001 % UInt
    return hash(x.index, hash(x.len, base ⊻ h))
end

Base.size(v::OneHotVector) = (v.len,)
Base.length(v::OneHotVector) = v.len

function Base.getindex(v::OneHotVector, i::Int)
    @boundscheck checkbounds(v, i)
    return i == v.index
end

Base.getindex(v::OneHotVector, ::Colon) = v
Base.argmax(v::OneHotVector) = v.index
Base.argmin(v::OneHotVector) = 1 + ((v.index == 1) & (length(v) != 1))
Base.count(::typeof(identity), v::OneHotVector) = 1
Base.allunique(v::OneHotVector) = length(v) < 3

for f in (:(Base.:+), :(Base.:-))
    @eval function ($f)(v::OneHotVector, v1::Vector)
        promote_shape(v, v1)
        c = copy(v1)
        @inbounds val = c[v.index]
        val = $(f)(val, one(eltype(v1)))
        @inbounds c[v.index] = val
        return c
    end
    @eval $(f)(v1::Vector, v::OneHotVector) = $(f)(v, v1)
end

Base.reverse(v::OneHotVector) = OneHotVector(length(v), length(v)-v.index+1, unsafe)

function Base.findfirst(f::Function, v::OneHotVector)
    ft::Bool = f(true)
    ff::Bool = f(false)
    ft & ff && return 1
    !(ft | ff) && return nothing
    ft && return v.index
    ff && return ifelse(length(v) == 1, nothing, 1 + v.index == 1)
end

function Base.circshift(v::OneHotVector, s::Integer)
    newindex = Int(mod1(v.index + s, length(v)))
    return OneHotVector(length(v), newindex, unsafe)
end
