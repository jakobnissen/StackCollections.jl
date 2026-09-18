using Test
using StackCollections: USet, UVec, pop, push, popfirst, pushfirst, append, deleteat, insert, capacity,
    maximum_member, can_contain, uset_from_integer

@testset "USet" begin
    include("uset.jl")
end

@testset "UVec" begin
    include("uvec.jl")
    include("editing.jl")
end
