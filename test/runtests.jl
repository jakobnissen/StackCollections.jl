using Test
using BitIntegers: UInt256, UInt512
using StackCollections: USet, UVec, pop, push, popfirst, pushfirst, append, deleteat, insert, capacity,
    maximum_member, can_contain, uset_from_bits, setindex, spliceinto

@testset "USet" begin
    include("uset.jl")
end

@testset "UVec" begin
    include("uvec.jl")
    include("editing.jl")
end
