# `USet`

A `USet{U <: Unsigned} <: AbstractSet{UInt32}` is an integer interpreted as a bit set of `UInt32`.

It is guaranteed to be an immutable struct with the same memory layout as a `U`, where the bits from LSB to MSB represent the presence of the elements `UInt32(0)` upwards.
For example, `USet{UInt16}([2, 9, 1, 7, 3])` is guaranteed to be stored in memory as `0x028e`.

These sets are ordered: Iteration is guaranteed to be in order from lowest to highest element, and `pop` and `popfirst` is guaranteed to remove the largest (last) and smallest (first) element, respectively.

As `USet`s are immutable, mutating operations like `push!` or `setdiff!` are not available. Instead, use non-mutating functions like `setdiff` which return new `USet`s. Since `USet`s are typically stored in registers, there is no efficiency gain from mutation.

This package exports the non-mutating operations `push`, `popfirst` and `pop`.
Use `pop(s, i)` to return a set without member `i`; absent or out-of-range members leave the set unchanged.
