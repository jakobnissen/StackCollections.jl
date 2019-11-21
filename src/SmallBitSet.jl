module SmallBitSet

struct Unsafe end
const unsafe = Unsafe()

struct StackBitSet{M} <: AbstractSet{Int}
    x::UInt

    function StackBitSet{M}(x::UInt, ::Unsafe) where M
        M isa Int || throw(TypeError(:StackBitSet, "", Int, typeof(M)))
        ((M ≤ Sys.WORD_SIZE) & (M > 0)) || throw(DomainError(M, "M must be 1:$(Sys.WORD_SIZE)"))
        new(x)
    end
end

mask(M) = UInt(1) << M - 1
StackBitSet{M}() where M = StackBitSet{M}(zero(UInt), unsafe)
StackBitSet() = StackBitSet{Sys.WORD_SIZE}(zero(UInt), unsafe)

@noinline function throw_StackBitSet_digit_err(::Val{M}) where M
    throw(ArgumentError("StackBitSet{$(M)} can only contain 0:$(M-1)"))
end

function StackBitSet{M}(v::UInt) where M
    v ≥ Sys.WORD_SIZE && throw_StackBitSet_digit_err(Val(M))
    StackBitSet{M}(v, unsafe)
end

function Base.convert(::Type{StackBitSet{M1}}, x::StackBitSet{M2}) where {M1, M2}
    if (M1 < M2) & (x.x & mask(M1) != x.x)
        throw_StackBitSet_digit_err(Val(M1))
    else
        return StackBitSet{M1}(x.x, unsafe)
    end
end

function StackBitSet{M}(itr) where M
    d = StackBitSet{M}()
    for i in itr
        d = push(d, convert(Int, i))
    end
    d
end
StackBitSet(itr) = StackBitSet{Sys.WORD_SIZE}(itr)

function Base.promote_rule(::Type{StackBitSet{M1}}, ::Type{StackBitSet{M2}}) where {M1, M2}
    StackBitSet{max(M1, M2)}
end

Base.copy(s::StackBitSet) = s
Base.empty(x::StackBitSet) = typeof(x)()
Base.isempty(x::StackBitSet) = iszero(x.x)
Base.:(==)(x::StackBitSet, y::StackBitSet) = x.x == y.x
Base.allunique(x::StackBitSet) = true

# Julia PR33300 - improved printing of AbstractSets make this obsolete
@static if VERSION < v"1.4"
    function Base.show(io::IO, s::StackBitSet{M}) where M
        print(io, "StackBitSet{$M}([", join(s, ','), "])")
    end
end

function Base.iterate(x::StackBitSet, state::Int=0)
    bits = x.x >>> unsigned(state)
    iszero(bits) && return nothing
    tz  = trailing_zeros(bits)
    res = state + tz
    return (res, res + 1)
end

Base.length(x::StackBitSet) = count_ones(x.x)
Base.minimum(x::StackBitSet) = first(x)
Base.maximum(x::StackBitSet) = last(x)

function Base.last(x::StackBitSet)
    isempty(x) && throw(ArgumentError("collection must be non-empty"))
    Sys.WORD_SIZE - 1 - leading_zeros(x.x)
end

function Base.in(x::Int, s::StackBitSet{M}) where M
    u = unsigned(x)
    (u < M) & isodd(s.x >>> u)
end

function push(s::StackBitSet, v::Int, ::Unsafe)
    typeof(s)(s.x | (1 << (unsigned(v) & (Sys.WORD_SIZE - 1))), unsafe)
end

function push(s::StackBitSet{M}, v::Int) where M
    unsigned(v) ≥ M && throw_StackBitSet_digit_err(Val(M))
    push(s, v, unsafe)
end

function delete(s::StackBitSet, v::Int)
    mask = ~(one(UInt) << unsigned(v))
    typeof(s)(s.x & mask, unsafe)
end

function pop(s::StackBitSet, v::Int)
    in(s, v) || throw(KeyError(v))
    delete(s, v)
end

for (func, op) in ((:union, :|), (:intersect, :&), (:symdiff, :⊻))
    @eval begin
        function Base.$(func)(x::StackBitSet, y::StackBitSet)
            promote_type(typeof(x), typeof(y))($op(x.x, y.x), unsafe)
        end

        Base.$(func)(x, y::StackBitSet) = $func(y, x)

        function Base.$(func)(x::StackBitSet, itr...)
            for i in itr
                y_ = typeof(x)(i)
                x = $func(x, y_)
            end
            x
        end
    end
end

Base.setdiff(x::StackBitSet, y::StackBitSet) where M = intersect(x, complement(y))
function Base.setdiff(x::StackBitSet, itr...)
    union_ = typeof(x)()
    for i in itr
        y_ = typeof(x)(i)
        union_ = union(union_, y_)
    end
    return setdiff(x, union_)
end

Base.issubset(x::StackBitSet, y::StackBitSet) = isempty(setdiff(x, y))
complement(x::StackBitSet{M}) where M = typeof(x)(x.x ⊻ mask(M), unsafe)
isdisjoint(x::StackBitSet, y::StackBitSet) = isempty(intersect(x, y))

export StackBitSet,
       push, delete,
       complement, isdisjoint

end # module
