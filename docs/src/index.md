```@meta
CurrentModule = StackCollections
DocTestSetup = quote
    using StackCollections
end
```

# StackCollections.jl

This package implements collections that are immutable and bitstypes.
The types in this package are:

* Small and non-allocating: Stored in a few registers
* Microoptimized: Methods have been crafted for highest performance.

Currently, the following types are implemented:

* `USet{U <: Unsigned} <: AbstractSet{UInt32}`: Integers as bit sets, which can contain integers in `UInt32(0):UInt32(B - 1)`, where `B` is the size of bits in `U`.
* `UVec{U <: Unsigned} <: AbstractVector{Bool}`: Integers as bit vectors.

These types are immutable, so instead of operations like `push!`, `pop!` and `deleteat!`,
this package exports several new non-mutating functions such as `push`, `pop` and `deletaat` based on the mutating `Base` functions, as well as some new functions such as [`spliceinto`](@ref) and [`capacity`](@ref)

## Installation and quickstart
StackCollections is registered in Julia's General Registry. Hence, users can add it by running `using Pkg; Pkg.add("StackCollections")`.

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

## The `USet` type
A `USet{U <: Unsigned} <: AbstractSet{UInt32}` is an immutable integer set backed by a `U`.
It is analogous to a bitstype version of `BitSet` from Base.

For an integer `U` with `B` bits, an `USet{U}` can contain the values `UInt32(0):UInt32(B - 1)`. Attempting to add `UInt32` values above that range to the set will throw an `ArgumentError`.

These sets are ordered: Iteration is guaranteed to be in order from lowest to highest element, and `pop` and `popfirst` is guaranteed to remove the largest (last) and smallest (first) element, respectively.

As `USet`s are immutable, mutating operations like `push!` or `setdiff!` are not available. Instead, use non-mutating functions like `push` or `setdiff` which return new `USet`s. Since `USet`s are typically stored in registers, and not allocated, there is no efficiency gain from mutating a `USet` over constructing a new one.

#### `USet` integer representation
A `USet{U}` is guaranteed to be an immutable struct with the same memory layout as a `U`, where the bits from LSB to MSB represent the presence of the elements `UInt32(0)` upwards.
For example, `USet{UInt16}([2, 9, 1, 7, 3])` is guaranteed to be stored in memory as `0x028e`.

You can obtain the wrapping integer with `Integer(::USet)`, and construct a `USet` directly from a backing `Unsigned` integer with `uset_from_bits(::Unsigned)`.
These operations optimize to noops.

#### `USet example usage`

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

A `UVec{U}` has a maximum length which is determined by the type of `U`. See the section below on how to choose `U`.

`UVec`s are immutable, so mutating operations like `push!`, `setindex!` or `deleteat!` are not available. This package exports non-mutating versions `push`, `setindex`, `deleteat` etc which are equivalent, but returns new `UVec`s instead of mutating the `UVec`. As `UVec`s are stored in registers, there is no efficiency gain from mutating a `UVec` compared to creating a new one.

#### `UVec` integer representation
`UVec{U}` are guaranteed to have the same memory layout as a single `U`. This integer packs both length and the vector itself. The specific packing/encoding scheme is an implementation detail.

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

### Choosing U for `USet{U}` and `UVec{U}`
The integer type `U` in `USet{U}` or `UVec{U}` may be any unsigned bitstype. The type restricts the maximum elements a `USet` can contain, and the maximum length of a `UVec`. Therefore, larger `U` types allow more flexibility with theF `USet` and `UVec` type.
A `USet{U}` can maximally contain `B - 1`, where `B` is the number of bits in `B`. The maximum length of a `T <: UVec` is given by `capacity(T)`.

Larger backing integers have two downsides:
1. `USet{U}` and `UVec{U}` are the same size in memory as a `U`, so significant memory savings can be had by sing e.g. `UVec{UInt16}` over `UVec{UInt64}`.
2. For `U` larget than the system word size (typically `UInt64`), operations tend to be significantly slower since CPUs don't tend to natively support larger integer sizes than the word size.

| U type  | USet max member | UVec max length |
|---------------------------------------------|
| UInt8   |               7 |               5 |
| UInt16  |              15 |              12 |
| UInt32  |              31 |              27 |
| UInt64  |              63 |              58 |
| UInt128 |             127 |             121 |

For larger bit integers than `UInt128`, integers, you can load the package `BitIntegers.jl`. 
