# StackCollections.jl

This package implements a immutable bitstype collections. 
Currently, the following are implemented:

* `USet{U <: Unsigned} <: AbstractSet{UInt32}`: Integers as bit sets, which can contain intergers in `UInt32(0):UInt32(n)`, where `n == bitsizeof(U) - 1`.
* `UVector{U <: Unsigned} <: AbstractVector{Bool}`: Intergers as bit vectors.

These types are immutable, so instead of operations like `push!`, `pop!` and `deleteat!`,
this package exports several new non-mutating functions such as `push`, `pop` and `deletaat`.
Operations on these types have been microoptimized.

## The `USet` type
A `USet{U <: Unsigned} <: AbstractSet{UInt32}` is an immutable integer set backed by a `U`.

These sets are ordered: Iteration is guaranteed to be in order from lowest to highest element, and `pop` and `popfirst` is guaranteed to remove the largest (last) and smallest (first) element, respectively.

As `USet`s are immutable, mutating operations like `push!` or `setdiff!` are not available. Instead, use non-mutating functions like `push` or `setdiff` which return new `USet`s. Since `USet`s are typically stored in registers, there is no efficiency gain from mutation.

### `USet` integer representation
A `USet{U}` is guaranteed to be an immutable struct with the same memory layout as a `U`, where the bits from LSB to MSB represent the presence of the elements `UInt32(0)` upwards.
For example, `USet{UInt16}([2, 9, 1, 7, 3])` is guaranteed to be stored in memory as `0x028e`.

You can obtain the wrapping integer with `Integer(::USet)`, and construct a `USet` directly from a backing `Unsigned` integer with `uset_from_integer(::Unsigned)`.
These operations optimize to noops.

## The `UVec` type

A `UVec{U <: Unsigned} <: AbstractVector{Bool}` is an immutable boolean vector backed by a `U`.
`UVec`s are immutable, so mutating operations like `push!`, `setindex!` or `deleteat!` are not available. This package exports non-mutating versions `push`, `setindex`, `deleteat` etc.

### `UVec` integer representation
`UVec{U}` are guaranteed to have the same memory layout as a single `U`.
