# StackCollections.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jakobnissen.github.io/StackCollections.jl/dev)
![CI](https://github.com/jakobnissen/StackCollections.jl/workflows/CI/badge.svg)
[![Codecov](https://codecov.io/gh/jakobnissen/StackCollections.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/jakobnissen/StackCollections.jl)

_Integer backed collections in Julia_
This package implements a few collection typed stored in machine integers.
Currently, the following types are implemented:

* `USet{U <: Unsigned} <: AbstractSet{UInt32}`: Immutable bit set backed by a `U`
* `UVec{U <: Unsigned} <: AbstractVector{Bool}`: Immutable boolean vector with the vector and the length packed into a `U`.

These types are easy to implement yourself, but this package provides value by providing many already-tested and highly optimised methods.

The types are immutable and so this package exports a number of non-mutating equivalents to Base's mutating methods, such as `pop`, `push`, and `deleteat`.

See [the documentation](https://jakobnissen.github.io/StackCollections.jl/dev) for more details.

## Examples
```julia
julia> using StackCollections

julia> s = USet{UInt32}([30, 11, 19, 4, 8]);

julia> s2 = setdiff(s, USet{UInt64}([1, 19, 12, 4]))
USet{UInt32} with 3 elements:
  0x00000008
  0x0000000b
  0x0000001e

julia> (s3, element) = pop(s2); element
0x0000001e

julia> s3
USet{UInt32} with 2 elements:
  0x00000008
  0x0000000b

julia> v = UVec{UInt16}([1, 0, 1, 1, 1, 0, 0, 1, 0, 1, 0]);

julia> reverse(v, 3, 9) |> println
Bool[1, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0]

``` 
