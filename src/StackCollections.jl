module StackCollections

@inline function left_shift(x::Integer, u::Unsigned)
    mask = 8 * sizeof(x) - 1
    return x << (u & mask)
end


@inline function right_shift(x::Integer, u::Unsigned)
    mask = 8 * sizeof(x) - 1
    return x >>> (u & mask)
end

bitwidth(T::Type{<:Integer}) = 8 * sizeof(T)
bitwidth(::U) where {U <: Integer} = bitwidth(U)

include("uset.jl")
include("uvec.jl")

export USet,
    UVec,
    push,
    pop

end # module
