using Test
using BitIntegers: UInt256, UInt512
using StackCollections: USet, UVec, pop, push, popfirst, pushfirst, append, deleteat, insert, capacity,
    maximum_member, can_contain, to_bits, from_bits, setindex, spliceinto

# A single top-level testset, so that failures in one testset do not prevent
# the others from running.
@testset "StackCollections" begin
    @testset "USet" begin
        include("uset.jl")
    end

    @testset "UVec" begin
        include("uvec.jl")
        include("editing.jl")
    end
end
