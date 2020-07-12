# StackCollections.jl

_Fixed-bit collections in Julia_

This package implements a few collection types that can be stored in one or a few machine integers:

* `DigitSet`: A set of integers 0:63
* `StackSet`: A set of integers N:N+63
* `StackVector{L}`: A boolean vector with a length `L` of up to 64.
* `OneHotVector`: A boolean vector with exactly one value `true`, rest `false`.

The main features of the types are:

* They are simple to use, implements the basic methods from `Base` you would expect such as `union` for sets and `reverse` for vectors:

```
julia> a = StackVector([true, true, false, true]); reverse(a)
4-element StackVector{4}:
 1
 0
 1
 1
```

* They are safe by default, and throws informative error messages if you attempt illegal or undefined operations.

```
julia> push(DigitSet(), 100)
ERROR: ArgumentError: DigitSet can only contain 0:63
```

* All types are immutable and so easier to reason about. Base methods that usually end with an exclamation mark such as `push!` instead must use `push`.

```
julia> push!(DigitSet(), 100)
ERROR: MethodError: no method matching push!(::DigitSet, ::Int64)
```

* They are _highly_ efficiently implemented, with most methods meticulously crafted for maximal performance.

```
julia> f(x, y) = length(setdiff(x, symdiff(x, y)));

julia> code_native(f, (DigitSet, DigitSet), debuginfo=:none)
    .section    __TEXT,__text,regular,pure_instructions
    movq    (%rsi), %rax
    andq    (%rdi), %rax
    popcntq %rax, %rax
    retq
    nopl    (%rax)
```

Stack collections can be instantiated from an iterable, for example `StackVector([true, false, true])`, but this is not optimally efficient. Alternatively, they can be directly constructed using the unexported `StackCollections.unsafe` trait. But be careful: The trait is called `unsafe` for a reason - when constructed this way, there is no checking the inputs.

```
julia> StackVector{3}(UInt(5), StackCollections.unsafe)
3-element StackVector{3}:
 1
 0
 1
```

This API follows SemVer 2.0.0. The API for this package is defined by the documentation.
