# AGENTS
This file provides guidance for AI agents working in this repository.
StackCollections.jl is a Julia package that provides high-performance, immutable collections types backed by bitstypes.
Its two main types are:
* `USet{U <: Unsigned} <: AbstractSet{UInt32}`: An implementation of a bit-set represented by a single integer whose type is generic.
* `UVec{U <: Unsigned} <: AbstractVector{Bool}`: A variable-length bit-vector, where both the length and the vector itself is packed into a single integer whose type is generic.

# Guidelines
* After making changes, attempt to format with `runic -i .` and alert the user if `Runic` is not on your PATH. Do not attempt to install it.
* Do not use leading underscores to mark internal names, such as naming a helper function `_do_stuff`. Instead name it simply `do_stuff`. Only use leading underscores in the case a public method immediately forwards to an internal implementation for dispatch reasons; in that case a public function `foo` may forward to `_foo`, and the underscore is used to disambiguate a public method from an *equivalent* internal method. 
* This package is high-performance. Be wary of unnecessary branches such as error checks in the code you write, and see if it can be safely optimised away. Be mindful of integer conversions, which may throw, and replace them with unchecked truncation with `%` where it is known to be correct and safe. 
