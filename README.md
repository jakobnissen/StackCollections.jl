# StackCollections.jl
Fixed-bit collections in Julia

This package implements a few collection types that can be stored in one or a few machine integers:

* `DigitSet`: A set of integers 0:63
* `StackSet`: A set of integers N:N+63
* `StackVector{L}`: A boolean vector with a length of up to 64.

The main features of the types are:
* They are simple to use, implements the basic methods from `Base` you would expect such as `union` for sets and `reverse` for vectors:
```
julia> a = StackVector{4}([true, true, false, true]); reverse(a)
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

This API follows SemVer 2.0.0. The API for this package is defined by the documentation.
