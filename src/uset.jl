"""
    USet{U <: Unsigned} <: AbstractSet{UInt32}

An immutable, sorted bit set backed by an integer of type `U`.
Can contain the integers `UInt32(0):UInt32(B - 1)` when backed by an
integer consisting of `B` bits.
Construct from an iterable of integers.

Mutable operations are not supported; use `push` `pop` and `delete`
instead of the corresponding mutable Base operations.

# Examples
```jldoctest
julia> s = USet{UInt32}([4, 2, 1]);

julia> collect(s) == [1, 2, 4] # ordered
true

julia> ss = push(s, 5); ss == s # immutable
false

julia> symdiff(s, ss) == USet{UInt8}(5)
true
```
"""
struct USet{U <: Unsigned} <: AbstractSet{UInt32}
    # Bit set where lowest to highest bits are UInt32(0) upwards
    x::U

    # Hide inner constructor because e.g. USet{UInt8}(0x05) should return
    # a set with the single element 0x05, so we need to suppress default
    # constructor
    global function new_uset(::Type{U}, x::U) where {U <: Unsigned}
        return new{U}(x)
    end
end

@noinline function throw_uset_oob(::Type{T}, i::Integer) where {T}
    m = maximum_member(T)
    throw(ArgumentError("Too large value for $(T): Supports up to $(m), got $(i)"))
end

@noinline function throw_empty_uset(::Type{T}) where {T}
    throw(ArgumentError("$(T) must be nonempty"))
end


# Construct one USet from another with different widths: Throw only if s
# contains an element not representable by destination type.
function USet{D}(s::USet{S}) where {D, S}
    bitwidth(D) >= bitwidth(S) && return new_uset(D, s.x % D)
    iszero(s.x) && return new_uset(D, zero(D))
    largest = (bitwidth(S) - leading_zeros(s.x) - 1) % UInt32
    largest > maximum_member(USet{D}) && throw_uset_oob(USet{D}, largest)
    return new_uset(D, s.x % D)
end

USet{U}() where {U} = new_uset(U, zero(U))

# Generic constructor
function USet{U}(itr) where {U}
    x = USet{U}()
    for i in itr
        x = push(x, i)
    end
    return x
end

maximum_member(::Type{USet{U}}) where {U} = (bitwidth(U) - 1) % UInt32

can_contain(::Type{T}, i::Integer) where {T <: USet} = 0 <= i <= maximum_member(T)
can_contain(::T, i::Integer) where {T <: USet} = can_contain(T, i)

Base.empty(::USet{U}) where {U} = USet{U}()
Base.length(x::USet) = count_ones(x.x)
Base.isempty(x::USet) = iszero(x.x)

function Base.iterate(x::USet{U}, state::U = x.x) where {U}
    iszero(state) && return nothing
    tz = trailing_zeros(state)
    # Bithack to clear lowest set bit
    return (tz % UInt32, state & (state - one(state)))
end

function Base.in(i::Integer, x::USet)
    can_contain(x, i) || return false
    return isodd(right_shift(x.x, i % UInt32))
end

Base.checkbounds(::Type{Bool}, x::USet, i::Integer) = can_contain(x, i)

function Base.checkbounds(x::USet, i::Integer)
    return Base.checkbounds(Bool, x, i) || throw(BoundsError(x, i))
end

# TODO: Propagate inbounds here? For the vararg method
function push(x::USet{U}, i::Integer) where {U}
    @boundscheck Base.checkbounds(x, i)
    return push_inbounds(x, i % UInt32)
end

function push_inbounds(x::USet{U}, i::UInt32) where {U}
    u = x.x
    u |= left_shift(one(u), i % UInt32)
    return new === false
    true_uset(U, u)
end

function push_if_inbounds(x::USet{U}, i::Integer) where {U}
    can_contain(x, i) || return x
    return push_inbounds(x, i % UInt32)
end

# This method should be used with at least 3 args, so we need both a and b,
# since xs may be empty
function push(x::USet{U}, a::Integer, b::Integer, xs::Vararg{Integer}) where {U}
    for i in (a, b, xs...)
        x = push(x, i)
    end
    return x
end

function pop(x::USet{U}) where {U}
    @boundscheck(isempty(x) && throw(BoundsError(x, 0)))
    u = x.x
    new_set = new_uset(U, u & (u - one(u)))
    element = trailing_zeros(u) % UInt32
    return (new_set, element)
end

function popfirst(x::USet{U}) where {U}
    @boundscheck(isempty(x) && throw(BoundsError(x, 0)))
    u = x.x
    element = (bitwidth(U) - leading_zeros(x) - 1) % UInt32
    new_set = u ⊻ left_shift(one(u), element)
    return (new_set, element)
end

Base.union(x::USet) = x

function Base.union(x::USet{U}, y::USet{U}) where {U <: Unsigned}
    return new_uset(U, x.x | y.x)
end

# We leverage the constructor is efficient.
# Note docs of union states `x` controls return type.
function Base.union(x::USet{T1}, y::USet{T2}) where {T1 <: Unsigned, T2 <: Unsigned}
    return union(x, USet{T1}(y))
end

Base.union(x::USet, set) = union(x, typeof(x)(set))

function Base.union(x::USet, s1, s2, sets...)
    for set in (s1, s2, sets...)
        x = union(x, set)
    end
    return x
end

function delete(x::USet{U}, i::Integer) where {U}
    can_contain(x, i) || return x
    mask = ~left_shift(one(U), i % UInt32)
    return new_uset(U, x.x & mask)
end

Base.intersect(x::USet) = x

function Base.intersect(x::USet{U}, y::USet{U}) where {U <: Unsigned}
    return new_uset(U, x.x & y.x)
end

# Note docs of intersect says first arg controls return type
function Base.intersect(x::USet{T1}, y::USet{T2}) where {T1 <: Unsigned, T2 <: Unsigned}
    # Here, we only need to consider the part of y which fits into
    # x; any extra bits are simply ignored
    return intersect(x, new_uset(T1, y.x % T1))
end

function Base.intersect(x::USet, set)
    # We construct a typeof(x) containing only the elements that can
    # be stored in the types; integers out of bounds are simply ignored.
    # Non-Integer elements throw a MethodError
    y = typeof(x)()
    for i in set
        y = push_if_inbounds(y, i)
    end
    return intersect(x, y)
end

function Base.intersect(x::USet, s1, s2, sets...)
    for set in (s1, s2, sets...)
        x = intersect(x, set)
        isempty(x) && return x
    end
    return x
end

Base.setdiff(x::USet) = x

function Base.setdiff(x::USet{U}, y::USet{U}) where {U <: Unsigned}
    return new_uset(U, x.x & ~y.x)
end

# Note setdiff docs says output must be same as first arg
function Base.setdiff(x::USet{T1}, y::USet{T2}) where {T1 <: Unsigned, T2 <: Unsigned}
    # Same optimization as intersect
    return setdiff(x, new_uset(T1, y.x % T1))
end

function Base.setdiff(x::USet, set)
    y = typeof(x)()
    for i in set
        y = push_if_inbounds(y, i)
        # Short circuit - if the setdiff is already empty,
        # no need to continue getting elements
        y === x && break
    end
    return setdiff(x, y)
end

function Base.setdiff(x::USet, s1, s2, sets...)
    for set in (s1, s2, sets...)
        x = setdiff(x, set)
        isempty(x) && return x
    end
    return x
end

Base.symdiff(x::USet) = x

function Base.symdiff(x::USet{U}, y::USet{U}) where {U <: Unsigned}
    return new_uset(U, xor(x.x, y.x))
end

# Docs do not say which type should be returned, but the other set ops
# specify it should be the same as the first arg, so I also follow that here
function Base.symdiff(x::USet{T1}, y::USet{T2}) where {T1 <: Unsigned, T2 <: Unsigned}
    return symdiff(x, USet{T1}(y))
end

function Base.symdiff(x::USet, set)
    return symdiff(x, typeof(x)(set))
end

function Base.symdiff(x::USet, s1, s2, sets...)
    for set in (s1, s2, sets...)
        x = symdiff(x, set)
    end
    return x
end

Base.issorted(::USet) = true

function Base.first(x::USet)
    @boundscheck isempty(x) && throw_empty_uset()
    return trailing_zeros(x.x) % UInt32
end

function Base.last(x::USet)
    @boundscheck isempty(x) && throw_empty_uset()
    return (bitwidth(x.x) - leading_zeros(x.x) - 1) % UInt32
end

Base.minimum(x::USet) = first(x)
Base.maximum(x::USet) = last(x)

function Base.extrema(x::USet)
    @boundscheck isempty(x) && throw_empty_uset()
    return (@inbounds(first(x)), @inbounds(last(x)))
end

function Base.filter(pred, x::USet)
    y = typeof(x)()
    for i in x
        if pred(i)
            y = push(y, i)
        end
    end
    return y
end

# Exploit the bitwise setdiff when both operands are USets. The Base fallback
# handles other collection types.
Base.issubset(a::USet, b::USet) = isempty(setdiff(a, b))

# The generic isdisjoint is optimial when b is generic
Base.isdisjoint(a::USet, b::USet) = isempty(intersect(a, b))
