module StackCollections

@inline function left_shift(x::Integer, u::Unsigned)
    mask = 8 * sizeof(x) - 1
    x << (u & mask)
end


@inline function right_shift(x::Integer, u::Unsigned)
    mask = 8 * sizeof(x) - 1
    x >>> (u & mask)
end

include("uset.jl")

export USet,
    push,
    pop

end # module
