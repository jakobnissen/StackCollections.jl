using StackCollections
using Test

@testset "DigitSet" begin
include("digitset.jl")
end

@testset "StackSet" begin
include("stackset.jl")
end

@testset "StackVector" begin
include("stackvector.jl")
end

@testset "OneHotVector" begin
include("onehotvector.jl")
end

@testset "Cross-type" begin
    @test hash(DigitSet([1, 6, 2])) != hash(StackSet([1, 6, 2]))
    @test hash(DigitSet([1, 6, 2])) == hash(DigitSet([1, 6, 2]))

    @test hash(StackVector([false, false, true])) != hash(OneHotVector([false, false, true]))
end
