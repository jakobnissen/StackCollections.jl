random_set() = DigitSet(rand(UInt))


@testset "Construction" begin
    @test DigitSet() === DigitSet()
    s = DigitSet([5, 1, 9, 8])
    s2 = DigitSet([9, 8, 1, 5])
    @test s === s2

    @test_throws ArgumentError DigitSet([-1, 5, 12])
    @test DigitSet([1, Int(5), 12]) === DigitSet([1, 12, 5, UInt(12)])
    @test_throws ArgumentError DigitSet([5, UInt8(12), 64])
    @test DigitSet([5, 12, 64]) === DigitSet([12, 5, 12, 5, 12])
end

@testset "Basic" begin
    e = DigitSet()
    @test isempty(e)
    @test DigitSet() === e
    @test empty(e) === e
    @test empty(random_set()) === e

    s = DigitSet([7, 28, 41, 11])
    s2 = DigitSet([7, 28, 41, 12])
    s3 = DigitSet([7, 28, 12])
    @test s != s2
    @test s != s3
    @test length(e) == 0
    @test length(s) == 4
    @test length(s2) == 4
    @test length(s3) == 3
end

@testset "Membership" begin
    for i in -1:64
        test !(i in DigitSet())
    end

    s = DigitSet([51, 11, 6, 32, 1, 0, 40])
    s2 = Set(DigitSet)
    for i in 0:63
        if i in s2
            @test (i in s)
        else
            @test !(i in s)
        end
    end

    @test (51 in s)
    @test !(50 in s)

    @test !(5 in DigitSet())
    @test !(0 in DigitSet())

#=

Iteration

Membership (in), minimum, maximum

Modification
    push
    filter
    pop
    delete

Set operations
    issubset
    isdisjoint
    union
    intersect
    symdiff
    setdiff


=#
