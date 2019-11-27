struct StackBitSet <: AbstractStackSet
    set::StackSet
    offset::Int # lowest value in set, 0 if empty elements

    StackBitSet(set::StackSet, offset::Int, ::Unsafe) = new(set, offset)
end

function StackBitSet(set::StackSet, offset::Int)
    s = StackBitSet(set, offset, unsafe)
    if !(isempty(set) | isodd(set.x))
        s = normalized(s)
    end
    return s
end

StackBitSet() = StackBitSet(StackSet(), 0, unsafe)
Base.empty(x::StackBitSet) = StackBitSet()
Base.isempty(x::StackBitSet) = isempty(x.set)

function StackBitSet(itr)
    d = StackBitSet()
    for i in itr
        d = push(d, convert(Int, i))
    end
    d
end

@noinline function throw_StackBitSet_range_err()
    throw(ArgumentError("StackSet can not contain values differing" *
                        "by more than $(Sys.WORD_SIZE-1)"))
end

function Base.iterate(s::StackBitSet, i::Int=0)
    it = iterate(s.set, i)
    it === nothing && return nothing
    return it[1]+s.offset, it[2]
end

function push(s::StackBitSet, x::Int, ::Unsafe)
    # Fake old offset for empty s, so we can increment s.offset
    oldoffset = ifelse(isempty(s), x, s.offset)
    newoffset = min(oldoffset, x)
    lshift = unsigned(s.offset - newoffset) & 63
    newset = push(StackSet(s.set.x << lshift), x-newoffset, unsafe)
    return StackBitSet(newset, newoffset, unsafe)
end

function push(s::StackBitSet, x::Int)
    !isempty(s) & (abs(x-s.offset) > 63) && throw_StackBitSet_range_err()
    return push(s, x, unsafe)
end

Base.length(x::StackSet) = length(x.set)
Base.maximum(x::StackBitSet) = maximum(x.set + x.offset)
Base.in(x::Int, s::StackBitSet) = in(x-s.offset, s.set)

function Base.filter(pred, s::StackBitSet)
    r = StackSet()
    for i in s.set
        pred(i+s.offset) && (r = push(r, i, unsafe))
    end
    normalized(StackBitSet(r, s.offset, unsafe))
end

pop(s::StackBitSet, v::Int) = in(s, v) ? delete(s, v, unsafe) : throw(KeyError(v))

function delete(s::StackBitSet, v::Int, ::Unsafe)
    normalized(delete(s.set, v-s.offset, unsafe), s.offset)
end
function delete(s::StackBitSet, v::Int)
    normalized(delete(s.set, v-s.offset), s.offset)
end

function Base.intersect(x::StackBitSet, y::StackBitSet)
    new_x_set = trunc_offset_stackset(x, y)
    normalized(StackBitSet(intersect(new_x_set, y.set), y.offset, unsafe))
end

function Base.setdiff(x::StackBitSet, y::StackBitSet)
    new_y_set = trunc_offset_stackset(y, x)
    normalized(StackBitSet(setdiff(x.set, new_y_set), x.offset, unsafe))
end
################
function trunc_offset_stackset(from::StackBitSet, to::StackBitSet)
    return StackSet(from.set.x >>> (to.offset - from.offset))
end

function normalized(s::StackBitSet)
    # Update offset and bitshift
    rshift = trailing_zeros(s.set.x) & 63
    s2 = StackBitSet(StackSet(s.set.x >>> unsigned(rshift)), s.offset + rshift, unsafe)
    return ifelse(isempty(s), StackBitSet(), s2)
end

# Return sets with lower offset, or non-empty's offset
function offset_to_lower(smaller::StackBitSet, bigger::StackBitSet)
    if (isempty(smaller) | isempty(bigger))
        return smaller.set, bigger.set
    end
    lshift = unsigned(bigger.offset - smaller.offset)
    leading_zeros(bigger.set.x) < lshift && throw_StackBitSet_range_err()
    shifted = bigger.set.x << (lshift & 63)
    return smaller.set, StackSet(shifted)
end

function Base.union(x::StackBitSet, y::StackBitSet)
    (smaller, bigger) = ifelse(x.offset < y.offset, (x, y), (y, x))
    sm_set, bg_set = offset_to_lower(smaller, bigger)
    return StackBitSet(union(sm_set, bg_set), smaller.offset, unsafe)
end

function Base.symdiff(x::StackBitSet, y::StackBitSet)
    (smaller, bigger) = ifelse(x.offset < y.offset, (x, y), (y, x))
    sm_set, bg_set = offset_to_lower(smaller, bigger)
    sbs = StackBitSet(symdiff(sm_set, bg_set), smaller.offset, unsafe)
    return normalized(sbs)
end

##########################
