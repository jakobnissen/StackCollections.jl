struct StackSet <: AbstractStackSet
    x::UInt

    StackSet(x::UInt) = new(x)
end

StackSet() = StackSet(zero(UInt))
function StackSet(itr)
    d = StackSet()
    for i in itr
        d = push(d, convert(Int, i))
    end
    d
end

@noinline function throw_StackSet_digit_err()
    throw(ArgumentError("StackSet can only contain 0:$(Sys.WORD_SIZE-1)"))
end

Base.empty(x::StackSet) = StackSet()
Base.isempty(x::StackSet) = iszero(x.x)
Base.:(==)(x::StackSet, y::StackSet) = x.x == y.x
Base.:⊊(x::StackSet, y::StackSet) = issubset(x, y) & (x != y)
Base.allunique(x::StackSet) = true

# Julia PR33300 - improved printing of AbstractSets make this obsolete
@static if VERSION < v"1.4"
    function Base.show(io::IO, s::AbstractStackSet)
        print(io, "$(typeof(s).name)([", join(s, ','), "])")
    end
end

function Base.iterate(x::StackSet, state::Int=0)
    bits = x.x >>> unsigned(state)
    iszero(bits) && return nothing
    tz  = trailing_zeros(bits)
    return (state + tz, state + tz + 1)
end

Base.in(x::Int, s::StackSet) = isodd(s.x >>> unsigned(x))
Base.length(x::StackSet) = count_ones(x.x)
Base.minimum(x::AbstractStackSet) = first(x)

function Base.maximum(x::StackSet)
    isempty(x) && throw(ArgumentError("collection must be non-empty"))
    Sys.WORD_SIZE - 1 - leading_zeros(x.x)
end

function push(s::StackSet, v::Int, ::Unsafe)
    StackSet(s.x | (1 << (unsigned(v) & (Sys.WORD_SIZE - 1))))
end

function push(s::StackSet, v::Int)
    unsigned(v) ≥ Sys.WORD_SIZE ? throw_StackSet_digit_err() : push(s, v, unsafe)
end

function Base.filter(pred, x::StackSet)
    r = StackSet()
    for i in x
        pred(i) && (r = push(r, i, unsafe))
    end
    r
end

pop(s::StackSet, v::Int) = in(s, v) ? delete(s, v, unsafe) : throw(KeyError(v))
delete(s::StackSet, v::Int) = ifelse(v ≥ Sys.WORD_SIZE, s, delete(s, v, unsafe))
function delete(s::StackSet, v::Int, ::Unsafe)
    mask = (typemax(UInt) - 1) << (unsigned(v) & (Sys.WORD_SIZE - 1))
    StackSet(s.x & mask)
end

Base.issubset(x::StackSet, y::StackSet) = isempty(setdiff(x, y))
isdisjoint(x::StackSet, y::StackSet) = isempty(intersect(x, y))
for (func, op) in ((:union, :|), (:intersect, :&), (:symdiff, :⊻))
    @eval begin
        function Base.$(func)(x::StackSet, y::StackSet)
            StackSet($op(x.x, y.x))
        end

        Base.$(func)(x, y::StackSet) = $func(y, x)
        function Base.$(func)(x::StackSet, itr...)
            for i in itr
                y_ = StackSet(i)
                x = $func(x, y_)
            end
            x
        end
    end
end

Base.setdiff(x::StackSet, y::StackSet) = StackSet(x.x & ~y.x)
function Base.setdiff(x::StackSet, itr...)
    union_ = StackSet
    for i in itr
        y_ = StackSet(i)
        union_ = union(union_, y_)
    end
    return setdiff(x, union_)
end
