module SmallBitSet

struct Unsafe end
const unsafe = Unsafe()

struct StackSet{M} <: AbstractSet{Int}
    x::UInt

    function StackSet{M}(x::UInt, ::Unsafe) where M
        M isa Int || throw(TypeError(:StackSet, "", Int, typeof(M)))
        ((M ≤ Sys.WORD_SIZE) & (M > 0)) || throw(DomainError(M, "M must be 1:$(Sys.WORD_SIZE)"))
        new(x)
    end
end

function StackSet{M}(v::UInt) where M
    v ≥ Sys.WORD_SIZE ? throw_StackSet_digit_err(Val(M)) : StackSet{M}(v, unsafe)
end

StackSet{M}() where M = StackSet{M}(zero(UInt), unsafe)
StackSet(x...) = StackSet{Sys.WORD_SIZE}(x...)
function StackSet{M}(itr) where M
    d = StackSet{M}()
    for i in itr
        d = push(d, convert(Int, i))
    end
    d
end

@noinline function throw_StackSet_digit_err(::Val{M}) where M
    throw(ArgumentError("StackSet{$(M)} can only contain 0:$(M-1)"))
end

function Base.convert(::Type{StackSet{M1}}, x::StackSet{M2}) where {M1, M2}
    if (M1 < M2) & (x.x & mask(M1) != x.x)
        throw_StackSet_digit_err(Val(M1))
    end
    return StackSet{M1}(x.x, unsafe)
end

function Base.promote_rule(::Type{StackSet{M1}}, ::Type{StackSet{M2}}) where {M1, M2}
    StackSet{max(M1, M2)}
end

mask(M) = UInt(1) << M - 1
Base.copy(s::StackSet) = s
Base.empty(x::StackSet) = typeof(x)()
Base.isempty(x::StackSet) = iszero(x.x)
Base.:(==)(x::StackSet, y::StackSet) = x.x == y.x
Base.allunique(x::StackSet) = true

# Julia PR33300 - improved printing of AbstractSets make this obsolete
@static if VERSION < v"1.4"
    function Base.show(io::IO, s::StackSet{M}) where M
        print(io, "StackSet{$M}([", join(s, ','), "])")
    end
end

function Base.iterate(x::StackSet, state::Int=0)
    bits = x.x >>> unsigned(state)
    iszero(bits) && return nothing
    tz  = trailing_zeros(bits)
    return (state + tz, state + tz + 1)
end

Base.length(x::StackSet) = count_ones(x.x)
Base.minimum(x::StackSet) = first(x)
Base.maximum(x::StackSet) = last(x)

function Base.last(x::StackSet)
    isempty(x) && throw(ArgumentError("collection must be non-empty"))
    Sys.WORD_SIZE - 1 - leading_zeros(x.x)
end

Base.in(x::Int, s::StackSet{M}) where M = (x < M) & isodd(s.x >>> unsigned(x))
function push(s::StackSet, v::Int, ::Unsafe)
    typeof(s)(s.x | (1 << (unsigned(v) & (Sys.WORD_SIZE - 1))), unsafe)
end

function push(s::StackSet{M}, v::Int) where M
    unsigned(v) ≥ M ? throw_StackSet_digit_err(Val(M)) : push(s, v, unsafe)
end

pop(s::StackSet, v::Int) = in(s, v) ? delete(s, v) : throw(KeyError(v))
function delete(s::StackSet, v::Int)
    mask = ~(one(UInt) << unsigned(v))
    typeof(s)(s.x & mask, unsafe)
end

Base.issubset(x::StackSet, y::StackSet) = isempty(setdiff(x, y))
complement(x::StackSet{M}) where M = typeof(x)(x.x ⊻ mask(M), unsafe)
isdisjoint(x::StackSet, y::StackSet) = isempty(intersect(x, y))
for (func, op) in ((:union, :|), (:intersect, :&), (:symdiff, :⊻))
    @eval begin
        function Base.$(func)(x::StackSet, y::StackSet)
            promote_type(typeof(x), typeof(y))($op(x.x, y.x), unsafe)
        end

        Base.$(func)(x, y::StackSet) = $func(y, x)
        function Base.$(func)(x::StackSet, itr...)
            for i in itr
                y_ = typeof(x)(i)
                x = $func(x, y_)
            end
            x
        end
    end
end

Base.setdiff(x::StackSet, y::StackSet) = intersect(x, complement(y))
function Base.setdiff(x::StackSet, itr...)
    union_ = typeof(x)()
    for i in itr
        y_ = typeof(x)(i)
        union_ = union(union_, y_)
    end
    return setdiff(x, union_)
end

export StackSet, push, delete, complement, isdisjoint
end # module
