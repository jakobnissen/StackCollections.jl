```@meta
CurrentModule = StackCollections
DocTestSetup = quote
    using StackCollections
end
```

# StackCollections.jl

This package implements immutable and isbits collections.
The types in this package are:

* Small and non-allocating: Isbits, so stored in registers or on the stack, rarely heap-allocated.
* Microoptimized: Methods have been crafted for high performance, avoiding branches and allocations where possible.

Currently, the following types are implemented:

* `USet{U <: Unsigned} <: AbstractSet{UInt32}`: Integers as bit sets, which can contain integers in `UInt32(0):UInt32(B - 1)`, where `B` is the number of bits in `U`.
* `UVec{U <: Unsigned} <: AbstractVector{Bool}`: Integers as bit vectors.

You may want to use StackCollections.jl to:
* Save memory, as the types are smaller than `BitSet` and `BitVector`.
* Improve performance, as operations on the StackCollection types are often more efficient.
## Installation and quickstart
StackCollections is registered in Julia's General Registry. Hence, users can add it by running `using Pkg; Pkg.add("StackCollections")`.

### Usage
```jldoctest
s = USet{UInt32}([5, 2, 1])
s2 = push(s, 19)
common = intersect(s, s2)
(s, largest) = pop(s2)

v = UVec{UInt8}([true, false, true, true])
v = setindex(v, false, 2)
v = push(v, false)
@assert v == [1, 0, 1, 1, 0]

# output
```

## Immutable operations
The types in this package are immutable collections.
Therefore, they do not support mutating operations you know from similar collections, such as `pop!`, `deleteat!` or `push!`.
Some of these operations are provided with similar non-mutating operations that return a new set, such as `push(s, i)`, which computes a new collection equal to `s` but with `i` added. Other operations have no direct equivalent, and are provided through new functions.

Since the types are small bitstypes, creating new copies of the collections is more performant than mutation would be, and so there is no performance downside to using the non-mutating operations. If mutation is desired, you may store an instance of some collection `T` in a `Ref{T}`, and then swap it out.

The following table can be used to find similar methods to known mutating operations. Note that besides returning new instances rather than mutating, the semantics might differ slightly. See each function's docstring for more details.

| Base function | Use instead  |
|---------------|--------------|
| `setindex!`   | `setindex`   |
| `push!`       | `push`       |
| `pushfirst!`  | `pushfirst`  |
| `pop!`        | `pop`        |
| `popfirst!`   | `popfirst`   |
| `deleteat!`   | `deleteat`   |
| `append!`     | `append`     |
| `insert!`     | `insert`     |
| `splice!`     | `spliceinto` |


## The `USet` type
A `USet{U <: Unsigned} <: AbstractSet{UInt32}` is an immutable integer set backed by a `U`.
It is analogous to a bitstype version of `BitSet` from Base.

For an integer `U` with `B` bits, a `USet{U}` can contain the values `UInt32(0):UInt32(B - 1)`. Attempting to add `UInt32` values above that range to the set will throw an `ArgumentError`.
For some operations, the error can be suppressed with `@inbounds`, in which case the functions return an arbitrary value (though guaranteed to be of the same type, and not incurring undefined behaviour).

A `USet` is ordered: Iteration is guaranteed to be in order from lowest to highest element, and `pop` and `popfirst` are guaranteed to remove the largest (last) and smallest (first) element, respectively.

Set operations and membership are determined by `isequal` rather than `==`.

#### Non-`UInt32` elements
`USet <: AbstractSet{UInt32}`. Operations on `USet` are intended to support `Integer`s, including negative integers and integers `> typemax(UInt32)`.
For example, given a `s::USet`, `-1 in s` is a valid query guaranteed to return `false`.
See [`can_contain`](@ref).

Some effort has been made to opportunistically support non-`Integer` types for `USet` queries; however, these queries are not optimally efficient, and the sheer number of possible types and semantics mean there may be some unintentional behaviour in edge cases.

Explicit support has been added for `Complex`, `Real` and `Missing` types, including edge cases like `-0.0 in USet{UInt8}([0.0])`, which correctly returns `false`, since `!isequal(UInt32(0), -0.0)`.

#### `USet` integer representation
A `USet{U}` is guaranteed to be an immutable struct with the same memory layout as a `U`, where the bits from LSB to MSB represent the presence of the elements `UInt32(0)` upwards.
For example, `USet{UInt16}([2, 9, 1, 7, 3])` is guaranteed to be stored in memory as `0x028e`.

You can obtain the wrapping integer with `to_bits(::USet)`, and construct a `USet` directly from a backing `Unsigned` integer with `from_bits(USet, ::Unsigned)`.
These operations optimize to noops.

#### `USet` example usage

```jldoctest
s = USet{UInt16}([4, 9, 11, 0])
@assert !in(55, s)

new_s, element = pop(s)
@assert element == 11 # largest element popped
@assert new_s === USet{UInt16}([9, 0, 4])
@assert length(s) == 4 # old s unchanged

s2 = intersect(s, [4, 9, 91])
@assert s2 === USet{UInt16}([9, 4])

# output
```

## The `UVec` type

A `UVec{U <: Unsigned} <: AbstractVector{Bool}` is an immutable boolean vector backed by a `U`. It is analogous to a `BitVector` from Base.

A `UVec{U}` has a maximum length which is determined by the type of `U`. The maximum length of a `T <: UVec` can be queried at compile time by `capacity(T)`.
See the section below on how to choose the right type for `U`.

Attempting to create a `UVec` longer than the maximum capacity will throw an `ArgumentError`.
For some operations, the error can be suppressed with `@inbounds`, in which case the functions return an arbitrary value (though guaranteed to be of the same type, and not incurring undefined behaviour).

#### `UVec` integer representation
`UVec{U}` is guaranteed to have the same memory layout as a single `U`. This integer packs both length and the vector itself. The specific packing/encoding scheme is an implementation detail, but it is guaranteed that:
* No distinct `UVec`s have the same backing integer.
* No distinct integers produce the same `UVec`: Either an integer is not a valid backing storage for `UVec`, or else it produces a unique `UVec`.

You can obtain the backing integer of a `v::UVec` with `to_bits(v)`, and construct a `UVec{U}` from a `u::U` with `from_bits(UVec, u)`.

#### `UVec` example usage

```jldoctest
v = UVec{UInt32}([1, 0, 1, 1, 0])
v2 = push(v, 1, 1, 0, 1)

@assert v2 == [1, 0, 1, 1, 0, 1, 1, 0, 1]
@assert length(v) == 5 # old one unchanged

v3 = reverse(v)
@assert v3 === UVec{UInt32}([0, 1, 1, 0, 1])

# output
```

## Choosing U for `USet{U}` and `UVec{U}`
The integer type `U` in `USet{U}` or `UVec{U}` may be any unsigned bitstype. The type restricts the maximum elements a `USet` can contain, and the maximum length of a `UVec`. Therefore, larger `U` types allow more flexibility with the `USet` and `UVec` type.
A `USet{U}` can maximally contain `B - 1`, where `B` is the number of bits in `U`. The maximum length of a `T <: UVec` is given by `capacity(T)`. 

| U type  | USet max member | `capacity(UVec{U})` |
|---------|-----------------|---------------------|
| UInt8   |               7 |                   5 |
| UInt16  |              15 |                  12 |
| UInt32  |              31 |                  27 |
| UInt64  |              63 |                  58 |
| UInt128 |             127 |                 121 |

### Large `U` types
For `U` larger than the system word size (typically `UInt64`), operations tend to be significantly slower, since CPUs don't tend to natively support larger integer sizes than the word size, and operations have to be expressed as multiple operations on word sized chunks.

For larger bit integers than `UInt128`, you can load the package `BitIntegers.jl`.
However, note that this package may not support some operations (notably, currently `bitreverse` is not supported), so some StackCollections.jl functions may not work with these larger integers.

### Non-power-of-two sized integers
This package was written before support for non-power-of-two integers (NPTI) was available in Julia. Hence, the behaviour for StackCollection types backed by NPTI is not tested, and may not be correct.
Support for backing by NPTI is planned eventually.
