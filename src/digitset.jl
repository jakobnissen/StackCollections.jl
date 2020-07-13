"""
    DigitSet([itr])

Construct a `DigitSet`, an `AbstractSet{Int}` which can only contains numbers 0:63.
A `DigitSet` is stored as a single integer in memory, and is immutable.

See also: [`StackSet`](@ref)
"""
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
    return hash(x.x, h ⊻ base)
end

@noinline function throw_DigitSet_digit_err()
    throw(ArgumentError("DigitSet can only contain 0:$(Sys.WORD_SIZE-1)"))
end

function show(io::IO, s::AbstractStackSet)
    print(io, "$(typeof(s))(")
    Base.show_vector(io, s)
    print(io, ')')
end

Base.empty(x::DigitSet) = DigitSet()
Base.isempty(x::DigitSet) = iszero(x.x)
Base.:(==)(x::T, y::T) where T<:AbstractStackSet = x === y
Base.:⊊(x::AbstractStackSet, y::AbstractStackSet) = issubset(x, y) & (x != y)
Base.allunique(x::AbstractStackSet) = true

function Base.iterate(x::DigitSet, state::Int=0)
    bits = x.x >>> unsigned(state)
    iszero(bits) && return nothing
    tz  = trailing_zeros(bits)
    return (state + tz, state + tz + 1)
end

Base.in(x::Int, s::DigitSet) = isodd(s.x >>> unsigned(x))
Base.length(x::DigitSet) = count_ones(x.x)

Base.maximum(x::DigitSet, ::Unsafe) = Sys.WORD_SIZE - 1 - leading_zeros(x.x)
function Base.maximum(x::DigitSet)
    isempty(x) && throw_empty_err()
    return maximum(x, unsafe)
end

Base.minimum(x::DigitSet, ::Unsafe) = trailing_zeros(x.x)
function Base.minimum(x::DigitSet)
    isempty(x) && throw_empty_err()
    return minimum(x, unsafe)
end

function push(s::DigitSet, v::Int, ::Unsafe)
    DigitSet(s.x | (1 << (unsigned(v) & (Sys.WORD_SIZE - 1))))
end

"""
    push(collection, items...)

Return a new collection containing all elements of `collection` and of `items`.
If `collection` is ordered, add the new element to the end.

# Examples

```jldoctest
julia> s = DigitSet([4, 9]);

julia> push(s, 1, 11)
DigitSet with 4 elements:
  1
  4
  9
  11
```
"""
function push end

function push(s::DigitSet, v::Int)
    unsigned(v) ≥ Sys.WORD_SIZE ? throw_DigitSet_digit_err() : push(s, v, unsafe)
end

function push(s::DigitSet, vs...)
    for v in vs
        s = push(s, convert(Int, v))
    end
    s
end

function Base.filter(pred, x::DigitSet)
    r = DigitSet()
    for i in x
        pred(i) && (r = push(r, i, unsafe))
    end
    r
end

"""
    pop(s::AbstractStackSet, v::Int)

Return a copy of `s` without `v`. If `v` is not in `s`, raise an error.
# Examples

```jldoctest
julia> s = DigitSet([4, 41, 9]);

julia> pop(s, 41)
DigitSet with 2 elements:
  4
  9
```

See also: [`delete`](@ref)
"""
function pop end

pop(s::AbstractStackSet, v::Int) = in(v, s) ? delete(s, v, unsafe) : throw(KeyError(v))

"""
    delete(s::AbstractStackSet, v::Int)

Return a copy of `s` that does not contain without `v`.

# Examples

```jldoctest
julia> s = DigitSet([4, 41, 9]);

julia> delete(s, 1)
DigitSet with 3 elements:
  4
  9
  41
```

See also: [`pop`](@ref)
"""
function delete end

delete(s::DigitSet, v::Int) = ifelse((v < 0) | (v ≥ Sys.WORD_SIZE), s, delete(s, v, unsafe))
function delete(s::DigitSet, v::Int, ::Unsafe)
    mask = ~(UInt(1) << (unsigned(v) & (Sys.WORD_SIZE - 1)))
    DigitSet(s.x & mask)
end

Base.issubset(x::AbstractStackSet, y::AbstractStackSet) = isempty(setdiff(x, y))

# isdisjoint was added to Base in 1.5
@static if VERSION < v"1.5"
    """
        isdisjoint(x, y) -> Bool

    Check if `x` and `y` have no elements in common.

    # Examples

    ```jldoctest
    julia> isdisjoint(DigitSet([1,6,4]), DigitSet([0, 61, 44]))
    true

    julia> isdisjoint(DigitSet([1,6,4]), DigitSet([4, 61, 44]))
    false

    julia> isdisjoint(DigitSet(), DigitSet())
    true
    ```
    """
    function isdisjoint end
    isdisjoint(x::AbstractStackSet, y::AbstractStackSet) = isempty(intersect(x, y))
else
    Base.isdisjoint(x::AbstractStackSet, y::AbstractStackSet) = isempty(intersect(x, y))
end

Base.setdiff(x::DigitSet, y::DigitSet) = DigitSet(x.x & ~y.x)

for (func, op) in ((:union, :|), (:symdiff, :⊻), (:intersect, :&))
    @eval begin
        function Base.$(func)(x::DigitSet, y::DigitSet)
            DigitSet($op(x.x, y.x))
        end
    end
end

# These functions work even if the collections in `itrs` contains elements not
# in 0:63.
for func in (:intersect, :setdiff)
    @eval begin
        function Base.$(func)(x::AbstractStackSet, itrs...)
            y = x
            for i in itrs
                z = typeof(x)()
                for j in i
                    if j in y
                        z = push(z, j)
                    end
                end
                y = $func(y, z)
            end
            return y
        end
    end
end

# This functions must fail if any item in a collection in `itrs` are not in
# the applicable domain, e.g. 0:63 for DigitSet
function Base.union(x::AbstractStackSet, itrs...)
    for i in itrs
        y_ = typeof(x)(i)
        x = union(x, y_)
    end
    return x
end

# This function needs to extend past 0:63, because it needs to keep track of
# which elements have been added and/or canceled by the iterables
Base.symdiff(x::AbstractStackSet, itrs...) = typeof(x)(symdiff(Set(x), itrs...))
