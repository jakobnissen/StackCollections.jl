# SmallBitSet.jl
Stack-allocated integer sets in Julia

A small toy project to show the conciseness, abstraction and speed of Julia.

This module implements one custom type - the `StackSet{M}`. A `StackSet{M}` is a set of integers in 0:(M-1) encoded in the lower M bits of a machine integer.

In 121 lines, this module implements:

* some basic methods: `copy`, `empty`, `isempty`, custom iteration, `length`, `minimum`, `maximum`, `last`, `in`, `push`, `delete` and `pop`.
* some set-specific methods: `allunique`, `union`, `intersect`, `setdiff`, `complement` and `isdisjoint`.
* As well as converters and constructors.

A `StackSet` behaves exactly like you would expect an `AbstractSet` to do - other than that it is immutable:

```
julia> a = StackSet(2i+3 for i in 2:3:16)
StackSet{64}([7,13,19,25,31])

julia> 7 in a ? length(union(a, a)) : length(intersect(a, complement(a)))
5
```

It is safe to use:
```
julia> pop(a, 6)
ERROR: KeyError: key 6 not found
Stacktrace:
 [1] pop(::Main.SmallBitSet.StackSet{64}, ::Int64) at /home/jakni/Documents/scripts/play/SmallBitSet.jl/src/SmallBitSet.jl:100
 [2] top-level scope at none:0

julia> push(a, -1)
ERROR: ArgumentError: StackSet{64} can only contain 0:63
Stacktrace:
 [1] throw_StackSet_digit_err(::Val{64}) at /home/jakni/Documents/scripts/play/SmallBitSet.jl/src/SmallBitSet.jl:21
 [2] push(::Main.SmallBitSet.StackSet{64}, ::Int64) at /home/jakni/Documents/scripts/play/SmallBitSet.jl/src/SmallBitSet.jl:90
 [3] top-level scope at none:0
```

And is *extremely* efficiently implemented, with most set operations done in single clock cycles:

```
julia> a, b = StackSet{11}(1:3:12), StackSet{41}(4:7:40);

julia> f(x, y) = length(setdiff(x, complement(y)));

julia> f(a, b)
1

julia> code_native(f, Tuple{typeof(a), typeof(b)}, debuginfo=:none)
    .text
    movq    (%rsi), %rax
    andq    (%rdi), %rax
    popcntq %rax, %rax
    retq
    nopl    (%rax)
```
