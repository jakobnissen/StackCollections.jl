"""
    StackSet([itr])

Construct a `StackSet`, an `AbstractSet{Int}` which can only contains numbers
N:N+63. A `Stackset` is stored in memory as a `DigitSet` and an integer offset,
and is immutable

See also: [`StackSet`](@ref)
"""
struct StackSet <: AbstractStackSet
    set::DigitSet
    offset::Int # lowest value in set, 0 if set is empty

    StackSet(set::DigitSet, offset::Int, ::Unsafe) = new(set, offset)
end

StackSet(set::DigitSet, offset::Int) = normalized(StackSet(set, offset, unsafe))

function Base.hash(x::StackSet, h::UInt)
    base = 0x30a9fa66b925af5a % UInt
    h = hash(base, h)
    h = hash(x.set, h)
    return hash(x.offset, h)
end

StackSet() = StackSet(DigitSet(), 0, unsafe)
Base.empty(x::StackSet) = StackSet()
Base.isempty(x::StackSet) = isempty(x.set)
Base.length(x::StackSet) = length(x.set)

function StackSet(itr)
    d = StackSet()
    for i in itr
        d = push(d, convert(Int, i))
    end
    d
end

@noinline function throw_StackSet_range_err()
    throw(ArgumentError("DigitSet can not contain values differing " *
                        "by more than $(Sys.WORD_SIZE-1)"))
end

function Base.iterate(s::StackSet, i::Int=0)
    it = iterate(s.set, i)
    it === nothing && return nothing
    return it[1]+s.offset, it[2]
end

function new_offset(s::StackSet, x::Int)
    # Returns new offset for stackset when pushing x in, and the shift.
    # if s is empty, shift result is arbitrary.
    newoffset = min(s.offset, x)
    return ifelse(isempty(s), x, newoffset), (s.offset - newoffset)
end

function push(s::StackSet, x::Int, ::Unsafe)
    newoffset, lshift = new_offset(s, x)
    newset = push(DigitSet(s.set.x << (lshift & 63)), x-newoffset, unsafe)
    return StackSet(newset, newoffset, unsafe)
end

function push(s::StackSet, x::Int)
    newoffset, lshift = new_offset(s, x)
    !isempty(s) & (leading_zeros(s.set.x) < lshift) && throw_StackSet_range_err()
    newset = push(DigitSet(s.set.x << (lshift & 63)), x-newoffset)
    return StackSet(newset, newoffset, unsafe)
end

Base.maximum(x::StackSet, ::Unsafe) = maximum(x.set, unsafe) + x.offset
Base.maximum(x::StackSet) = maximum(x.set) + x.offset
Base.minimum(x::StackSet, ::Unsafe) = minimum(x.set, unsafe) + x.offset
Base.minimum(x::StackSet) = minimum(x.set) + x.offset
Base.in(x::Int, s::StackSet) = in(x-s.offset, s.set)

function Base.filter(pred, s::StackSet)
    r = DigitSet()
    for i in s.set
        pred(i+s.offset) && (r = push(r, i, unsafe))
    end
    normalized(StackSet(r, s.offset, unsafe))
end

delete(s::StackSet, v::Int) = StackSet(delete(s.set, v-s.offset), s.offset)
pop(s::StackSet, v::Int) = in(v, s) ? delete(s, v) : throw(KeyError(v))

function Base.intersect(x::StackSet, y::StackSet)
    new_x_set = trunc_offset_stackset(x, y)
    normalized(StackSet(intersect(new_x_set, y.set), y.offset, unsafe))
end

function Base.setdiff(x::StackSet, y::StackSet)
    new_y_set = trunc_offset_stackset(y, x)
    normalized(StackSet(setdiff(x.set, new_y_set), x.offset, unsafe))
end

# This shifts the from bits to match the to bits, truncating if necessary
function trunc_offset_stackset(from::StackSet, to::StackSet)
    return DigitSet(from.set.x >>> (to.offset - from.offset))
end

function normalized(s::StackSet)
    rshift = trailing_zeros(s.set.x)
    offset = ifelse(isempty(s), 0, s.offset + rshift)
    return StackSet(DigitSet(s.set.x >>> (rshift & 63)), offset, unsafe)
end

# Returns DigitSets both with the lowest set's offset
# throws an error if any information would be lost by bitshifts.
# It is assumed none of the sets are empty
@inline function offset_to_lower(smaller::StackSet, bigger::StackSet)
    lshift = unsigned(bigger.offset - smaller.offset)
    unsigned(leading_zeros(bigger.set.x)) < lshift && throw_StackSet_range_err()
    shifted = bigger.set.x << (lshift & 63)
    return smaller.set, DigitSet(shifted)
end

function Base.union(x::StackSet, y::StackSet)
    isempty(x) && return y
    isempty(y) && return x
    (smaller, bigger) = ifelse(x.offset < y.offset, (x, y), (y, x))
    sm_set, bg_set = offset_to_lower(smaller, bigger)
    return StackSet(union(sm_set, bg_set), smaller.offset, unsafe)
end

function Base.symdiff(x::StackSet, y::StackSet)
    isempty(x) && return y
    isempty(y) && return x
    (smaller, bigger) = ifelse(x.offset < y.offset, (x, y), (y, x))
    sm_set, bg_set = offset_to_lower(smaller, bigger)

    # Unlike for union, we need to normalize here, so no unsafe construction
    return StackSet(symdiff(sm_set, bg_set), smaller.offset)
end
