"""
    USet{U <: Unsigned} <: AbstractSet{UInt32}

An immutable, sorted bit set backed by an integer of type `U`.
Can contain the integers `UInt32(0):UInt32(B - 1)` when backed by an
integer consisting of `B` bits.

Construct from an iterable of integers, or an empty set with `USet{U}()`.

Operations that would introduce an unrepresentable member, or require a
nonempty set when given an empty one, throw an `ArgumentError`. These checks
can sometimes be disabled locally with `@inbounds`.

`intersect` and `setdiff` with a generic collection accept `Real` and `Complex`
elements, and ignore those that are not `isequal` to a representable member,
such as `0.5`, `-0.0` or `1.0 - 0.0im`. Other element types throw a `MethodError`.

Mutable operations are not supported; use `push`, `pop` and `popfirst`
instead of the corresponding mutable Base operations.

The memory of this type is guaranteed to be identical to a `U`,
where set bits from LSB to MSB represent the presence of the integers
zero and upwards. I.e. `USet{UInt8}([0, 3, 5])` is guaranteed to have the same
memory layout as `0x29`.
Obtain the equivalent integer with `Integer(s)`. This is guaranteed to be
a noop. Construct from the equivalent integer with [`uset_from_bits`](@ref)

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
    global function new_uset(x::U) where {U <: Unsigned}
        return new{U}(x)
    end
end

function Base.show(io::IO, x::USet)
    v = collect(x)
    inner = if length(v) > 20
        join(v[1:10], ", ") * " … " * join(v[(end - 9):end], ", ")
    else
        join(v, ", ")
    end
    return print(io, typeof(x), "([", inner, "])")
end

@noinline function throw_uset_oob(::Type{T}, i::Integer) where {T}
    m = maximum_member(T)
    throw(ArgumentError("Value out of range for $(T): Supports 0:$(m), got $(i)"))
end

@noinline function throw_empty_uset(::Type{T}) where {T}
    throw(ArgumentError("$(T) must be nonempty"))
end

@noinline function throw_member_missing(::Type{T}, i) where {T}
    throw(ArgumentError("Item $(i) not present in $(T)"))
end

# Construct one USet from another with different widths: Throw only if s
# contains an element not representable by destination type.
@inline function USet{D}(s::USet{S}) where {D, S}
    @boundscheck if bitwidth(D) < bitwidth(S) && !isempty(s)
        largest = highestbit(s.x) % UInt32
        largest > maximum_member(USet{D}) && throw_uset_oob(USet{D}, largest)
    end
    return new_uset(s.x % D)
end

USet{U}() where {U} = new_uset(zero(U))

# Leave generic iteration to the compiler's normal inlining heuristics.
function USet{U}(itr) where {U}
    x = USet{U}()
    for i in itr
        x = push(x, i)
    end
    return x
end

# N.B: We only convert from USet and not AbstractSet{<:Integer} in general
# because I want conversion here to be fast, as convert is called implicitly
Base.convert(::Type{USet{D}}, x::USet) where {D} = USet{D}(x)
Base.convert(::Type{USet{U}}, x::USet{U}) where {U} = x

maximum_member(::Type{USet{U}}) where {U} = (bitwidth(U) - 1) % UInt32

"""
    can_contain(::Type{<:USet{U}}, i::Union{Real, Complex})::Bool

Return whether a `USet{U}` can contain an element `isequal` to `i`, by checking if
`i` is an integer in `0:maximum_member(USet{U})`.
Values that are numerically equal to such an integer, but not `isequal` to it,
such as `-0.0` or `1.0 - 0.0im`, cannot be contained.

```jldoctest
julia> can_contain(USet{UInt32}, 55)
false

julia> can_contain(USet{UInt64}, 55)
true

julia> can_contain(USet{UInt8}, 2.0 + 0im)
true

julia> can_contain(USet{UInt8}, -0.0)
false
```
"""
can_contain(::Type{T}, i::Integer) where {T <: USet} = 0 <= i <= maximum_member(T)

# The signbit check rejects -0.0, which is not isequal to 0
function can_contain(::Type{T}, i::Real) where {T <: USet}
    return isinteger(i) && !signbit(i) && i <= maximum_member(T)
end

# A complex number is only isequal to a real if its imaginary part is +0
function can_contain(::Type{T}, z::Complex) where {T <: USet}
    return is_positive_zero(imag(z)) && can_contain(T, real(z))
end

can_contain(::T, i::Union{Real, Complex}) where {T <: USet} = can_contain(T, i)

is_positive_zero(x::Real) = iszero(x) & !signbit(x)

# Get the member isequal to `i`. Only valid if `can_contain(T, i)`.
unchecked_member(i::Integer) = i % UInt32
unchecked_member(i::AbstractFloat) = unsafe_trunc(UInt32, i)
unchecked_member(i::Real) = Integer(i) % UInt32
unchecked_member(z::Complex) = unchecked_member(real(z))

Base.empty(::USet{U}) where {U} = USet{U}()
Base.length(x::USet) = count_ones(x.x)
Base.isempty(x::USet) = iszero(x.x)
Base.copy(x::USet) = x

"""
    Integer(x::USet{U})::U

Get the integer backing `x`. This integer is guaranteed to be a bit mask
where the N-th zero-indexed bit from lowest to highest bit represents the
presence of the element N in `x`.

See also: [`uset_from_bits`](@ref)

# Examples
```jldoctest
julia> s = USet{UInt16}([4, 11, 8, 2, 6]);

julia> u = Integer(s);

julia> u === 0x0954
true

julia> uset_from_bits(u) === s
true
```
"""
Base.Integer(x::USet) = x.x

"""
    uset_from_bits(u::U)::USet{U} where {U <: Unsigned}

Construct a `USet{U}` using the backing integer `u`.
For bitstype `U`, it is guaranteed that `Integer(uset_from_bits(u)) === u`.

The resulting `USet` contains the elements represented by the set
bits in `u`, from `UInt32(0)` being the LSB, and `UInt32(bitsizeof(U) - 1)`
is the MSB.

This operation is guaranteed to be optimizable to a noop.

```jldoctest
julia> u = 0x50ae; s = uset_from_bits(u);

julia> s isa USet{UInt16}
true

julia> s == Set([i for i in 0:16 if isodd(u >> i)])
true

julia> Integer(s) === u
true
```
"""
uset_from_bits(u::Unsigned) = new_uset(u)

function Base.iterate(x::USet{U}, state::U = x.x) where {U}
    iszero(state) && return nothing
    tz = trailing_zeros(state)
    return (tz % UInt32, clearlowest(state))
end

function Base.in(i::Union{Real, Complex}, x::USet)
    can_contain(x, i) || return false
    return testbit(x.x, unchecked_member(i))
end

# Fallback for other types, which could in principle be isequal to an integer.
# Set operations reject these, but `in` must not throw, since e.g. `==` between
# sets relies on it.
Base.in(i, x::USet) = any(j -> isequal(i, j), x)

Base.checkbounds(::Type{Bool}, x::USet, i::Integer) = can_contain(x, i)

function Base.checkbounds(x::USet, i::Integer)
    return Base.checkbounds(Bool, x, i) || throw(BoundsError(x, i))
end

@inline function push(x::USet{U}, i::Integer) where {U}
    @boundscheck can_contain(x, i) || throw_uset_oob(typeof(x), i)
    return push_inbounds(x, i % UInt32)
end

function push_inbounds(x::USet{U}, i::UInt32) where {U}
    u = x.x
    u |= singlebit(U, i)
    return new_uset(u)
end

# Push the member isequal to `i`, if any. Other types deliberately have no method,
# so that set operations throw a MethodError instead of doing a linear scan.
function push_if_inbounds(x::USet, i::Union{Real, Complex})
    can_contain(x, i) || return x
    return push_inbounds(x, unchecked_member(i))
end

# This method should be used with at least 3 args, so we need both a and b,
# since xs may be empty
function push(x::USet{U}, a::Integer, b::Integer, xs::Vararg{Integer}) where {U}
    for i in (a, b, xs...)
        x = push(x, i)
    end
    return x
end

@inline function pop(x::USet{U}) where {U}
    @boundscheck(isempty(x) && throw_empty_uset(typeof(x)))
    u = x.x
    element = highestbit(u) % UInt32
    new_set = new_uset(u ⊻ singlebit(U, element))
    return (new_set, element)
end

@inline function popfirst(x::USet{U}) where {U}
    @boundscheck(isempty(x) && throw_empty_uset(typeof(x)))
    u = x.x
    element = trailing_zeros(u) % UInt32
    new_set = new_uset(clearlowest(u))
    return (new_set, element)
end

Base.union(x::USet) = x

function Base.union(x::USet{U}, y::USet{U}) where {U <: Unsigned}
    return new_uset(x.x | y.x)
end

# We leverage the constructor is efficient.
# Note docs of union states `x` controls return type.
Base.@propagate_inbounds function Base.union(x::USet{T1}, y::USet{T2}) where {T1 <: Unsigned, T2 <: Unsigned}
    return union(x, USet{T1}(y))
end

Base.@propagate_inbounds Base.union(x::USet, set) = union(x, typeof(x)(set))

function Base.union(x::USet, s1, s2, sets...)
    for set in (s1, s2, sets...)
        x = union(x, set)
    end
    return x
end

"""
    pop(s::USet{U}, i::Integer)::Tuple{USet{U}, UInt32}

Return `(new_s, item)`, where `item` is equal to `i`,
and `new_s` is a copy of `s` but with `item` removed.

Throw an `ArgumentError` if `i` is not in `s`. This error may be suppressed
with `@inbounds`, in which case this operation may give nonsensical results.

```jldoctest
julia> s = USet{UInt8}([0, 2, 3, 6]);

julia> (new_s, item) = pop(s, 2); item === UInt32(2)
true

julia> new_s === typeof(s)([0, 6, 3])
true

julia> pop(s, 99999)
ERROR: ArgumentError: Item 99999 not present in USet{UInt8}
[...]
```
"""
function pop(x::USet{U}, i::Integer) where {U}
    @boundscheck if !in(i, x)
        throw_member_missing(USet{U}, i)
    end
    i32 = (i % UInt32)::UInt32
    return (new_uset(x.x & ~singlebit(U, i32)), i32)
end

Base.intersect(x::USet) = x

function Base.intersect(x::USet{U}, y::USet{U}) where {U <: Unsigned}
    return new_uset(x.x & y.x)
end

# Note docs of intersect says first arg controls return type
function Base.intersect(x::USet{T1}, y::USet{T2}) where {T1 <: Unsigned, T2 <: Unsigned}
    # Here, we only need to consider the part of y which fits into
    # x; any extra bits are simply ignored
    return intersect(x, new_uset(y.x % T1))
end

function Base.intersect(x::USet, set)
    # We construct a typeof(x) containing only the elements that can
    # be stored in the types; numbers not isequal to any possible member are
    # simply ignored. Elements that are not Real or Complex throw a MethodError
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
    return new_uset(x.x & ~y.x)
end

# Note setdiff docs says output must be same as first arg
function Base.setdiff(x::USet{T1}, y::USet{T2}) where {T1 <: Unsigned, T2 <: Unsigned}
    # Same optimization as intersect
    return setdiff(x, new_uset(y.x % T1))
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
    return new_uset(xor(x.x, y.x))
end

# Docs do not say which type should be returned, but the other set ops
# specify it should be the same as the first arg, so I also follow that here
Base.@propagate_inbounds function Base.symdiff(x::USet{T1}, y::USet{T2}) where {T1 <: Unsigned, T2 <: Unsigned}
    return symdiff(x, USet{T1}(y))
end

Base.@propagate_inbounds function Base.symdiff(x::USet, set)
    return symdiff(x, typeof(x)(set))
end

function Base.symdiff(x::USet, s1, s2, sets...)
    for set in (s1, s2, sets...)
        x = symdiff(x, set)
    end
    return x
end

Base.issorted(::USet) = true

@inline function Base.first(x::USet)
    @boundscheck isempty(x) && throw_empty_uset(typeof(x))
    return trailing_zeros(x.x) % UInt32
end

@inline function Base.last(x::USet)
    @boundscheck isempty(x) && throw_empty_uset(typeof(x))
    return highestbit(x.x) % UInt32
end

Base.@propagate_inbounds Base.minimum(x::USet) = first(x)
Base.@propagate_inbounds Base.maximum(x::USet) = last(x)

@inline function Base.extrema(x::USet)
    @boundscheck isempty(x) && throw_empty_uset(typeof(x))
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
