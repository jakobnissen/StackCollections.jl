using Test
using StackCollections: USet, UVec, pop, push, popfirst, pushfirst, append, delete, capacity,
    maximum_member, can_contain

@testset "USet" begin
    include("uset.jl")
end

@testset "UVec" begin
    include("uvec.jl")
end
