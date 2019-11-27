struct DigitSet <: AbstractStackSet
    x::UInt

    DigitSet(x::UInt) = new(x)
end

DigitSet() = DigitSet(zero(UInt))
function DigitSet(itr)
    d = DigitSet()
    for i in itr
        d = push(d, convert(Int, i))
    end
    d
end

function Base.hash(x::DigitSet, h::UInt)
    base = 0x0cabd57b4f53416a % UInt
    h = hash(base, h)
    return hash(x.x, h)
end

@noinline function throw_DigitSet_digit_err()
    throw(ArgumentError("DigitSet can only contain 0:$(Sys.WORD_SIZE-1)"))
end

Base.empty(x::DigitSet) = DigitSet()
Base.isempty(x::DigitSet) = iszero(x.x)
Base.:(==)(x::AbstractStackSet, y::AbstractStackSet) = x === y
Base.:⊊(x::DigitSet, y::DigitSet) = issubset(x, y) & (x != y)
Base.allunique(x::AbstractStackSet) = true

# Julia PR33300 - improved printing of AbstractSets make this obsolete
@static if VERSION < v"1.4"
    function Base.show(io::IO, s::AbstractStackSet)
        print(io, "$(typeof(s).name)([", join(s, ','), "])")
    end
end

function Base.iterate(x::DigitSet, state::Int=0)
    bits = x.x >>> unsigned(state)
    iszero(bits) && return nothing
    tz  = trailing_zeros(bits)
    return (state + tz, state + tz + 1)
end

Base.in(x::Int, s::DigitSet) = isodd(s.x >>> unsigned(x))
Base.length(x::DigitSet) = count_ones(x.x)
Base.minimum(x::AbstractStackSet) = first(x)

function Base.maximum(x::DigitSet)
    isempty(x) && throw(ArgumentError("collection must be non-empty"))
    Sys.WORD_SIZE - 1 - leading_zeros(x.x)
end

function push(s::DigitSet, v::Int, ::Unsafe)
    DigitSet(s.x | (1 << (unsigned(v) & (Sys.WORD_SIZE - 1))))
end

function push(s::DigitSet, v::Int)
    unsigned(v) ≥ Sys.WORD_SIZE ? throw_DigitSet_digit_err() : push(s, v, unsafe)
end

function Base.filter(pred, x::DigitSet)
    r = DigitSet()
    for i in x
        pred(i) && (r = push(r, i, unsafe))
    end
    r
end

pop(s::AbstractStackSet, v::Int) = in(s, v) ? delete(s, v, unsafe) : throw(KeyError(v))
delete(s::DigitSet, v::Int) = ifelse(v ≥ Sys.WORD_SIZE, s, delete(s, v, unsafe))
function delete(s::DigitSet, v::Int, ::Unsafe)
    mask = (typemax(UInt) - 1) << (unsigned(v) & (Sys.WORD_SIZE - 1))
    DigitSet(s.x & mask)
end

Base.issubset(x::DigitSet, y::DigitSet) = isempty(setdiff(x, y))
isdisjoint(x::DigitSet, y::DigitSet) = isempty(intersect(x, y))
for (func, op) in ((:union, :|), (:intersect, :&), (:symdiff, :⊻))
    @eval begin
        function Base.$(func)(x::DigitSet, y::DigitSet)
            DigitSet($op(x.x, y.x))
        end

        Base.$(func)(x, y::DigitSet) = $func(y, x)
        function Base.$(func)(x::DigitSet, itr...)
            for i in itr
                y_ = DigitSet(i)
                x = $func(x, y_)
            end
            x
        end
    end
end

Base.setdiff(x::DigitSet, y::DigitSet) = DigitSet(x.x & ~y.x)
function Base.setdiff(x::DigitSet, itr...)
    union_ = DigitSet
    for i in itr
        y_ = DigitSet(i)
        union_ = union(union_, y_)
    end
    return setdiff(x, union_)
end
