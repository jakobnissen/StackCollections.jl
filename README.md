# SmallBitSet.jl
Stack-allocated integer sets in Julia

A small toy project to show the conciseness, abstraction and speed of Julia.

This module implements one custom type - the `StackBitSet{M}`. A `StackBitSet{M}` is a set of integers in 0:(M-1) encoded in the 64 bits of this structs.

In 139 lines, this module implements:

* some basic methods: `copy`, `empty`, `isempty`, , custom iteration, `length`, `minimum`, `maximum`, `last`, `in`, `push`, `delete` and `pop`.
* some set-specific methods: `allunique`, `union`, `intersect`, `setdiff`, `complement` and `isdisjoint`.
* As well as converters and constructors.

A `StackBitSet` behaves exactly like an `AbstractSet`:

```
julia> a = StackBitSet([11, 51, 0, 27])
StackBitSet{64}([0,11,27,51])

julia> length(union(a, a))
4
```

And is *extremely* efficiently implemented, with most set operations done in single clock cycles:

```
julia> a, b = StackBitSet{11}([1, 5, 9, 0]), StackBitSet{41}([31, 21, 1, 0]);

julia> f(x, y) = length(setdiff(x, complement(y)));

julia> code_native(f, Tuple{typeof(a), typeof(b)}, debuginfo=:none)
    .section    __TEXT,__text,regular,pure_instructions
    movq    (%rsi), %rax
    andq    (%rdi), %rax
    popcntq %rax, %rax
    retq
    nopl    (%rax)
```
