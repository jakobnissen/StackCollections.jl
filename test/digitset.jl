random_set() = DigitSet(rand(UInt))

@testset "Construction" begin
    @test DigitSet() === DigitSet()
    s = DigitSet([5, 1, 9, 8])
    s2 = DigitSet([9, 8, 1, 5])
    @test s === s2

    @test_throws ArgumentError DigitSet([-1, 5, 12])
    @test DigitSet([1, Int(5), 12]) === DigitSet([1, 12, 5, UInt(12)])
    @test_throws ArgumentError DigitSet([5, UInt8(12), 64])
    @test DigitSet([5, 12]) === DigitSet([12, 5, 12, 5, 12])
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
        @test !(i in DigitSet())
    end
    s = DigitSet([51, 11, 6, 32, 1, 0, 40])
    s2 = Set(s)
    for i in -1:64
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
end

@testset "Iteration" begin
    s = DigitSet([19])
    v, st = iterate(s)
    @test v == 19
    @test iterate(s, st) === nothing
    v = [11, 8, 9, 13, 9, 12, 11, 61]
    s = DigitSet(v)
    @test Set(s) == Set(v)
end

@testset "Minimum & Maximum" begin
    @test_throws ArgumentError maximum(DigitSet())
    @test_throws ArgumentError minimum(DigitSet())

    @test maximum(DigitSet([3])) == 3
    @test minimum(DigitSet([3])) == 3

    s = DigitSet([4, 19, 28, 4, 1, 11])
    @test minimum(s) == 1
    @test maximum(s) == 28
end

@testset "Push" begin
    s = DigitSet([21, 22, 19])
    @test_throws ArgumentError push(s, -1)
    @test_throws ArgumentError push(s, 75)

    @test push(s, 21) == s
    @test push(s, 21, 19) == s

    s2 = push(s, 11)
    @test 11 in s2
    @test !(11 in s)
end

@testset "Filter" begin
    vs = [[], [0, 21], [11, 5, 11, 2], [6,7,8,9,0,42]]
    for F in [isodd, x -> true, x -> false, isequal(11)]
        for v in vs
            @test DigitSet(filter(F, Set(v))) == filter(F, DigitSet(v))
        end
    end
end

@testset "Pop & Delete" begin
    for v in [[], [0, 21], [11, 5, 11, 2], [6,7,8,9,0,42]]
        s´ = Set(v)
        s = DigitSet(v)

        for i in [-5, 0, 5, 11, 9, 42, 64, 99]
            if i in s´
                for (F, F!) in [[pop, pop!], [delete, delete!]]
                    s2´ = copy(s´)
                    F!(s2´, i)
                    @test Set(F(s, i)) == s2´
                end
            else
                @test_throws KeyError pop(s, i)
                @test delete(s, i) == s
            end
        end
    end
end

@testset "Isdisjoint" begin
    @test isdisjoint(DigitSet(), DigitSet())

    s = DigitSet([1,5,6])
    @test !isdisjoint(s, s)
    @test !isdisjoint(s, push(s, 9))

    @test isdisjoint(DigitSet([41, 21, 9]), DigitSet([40, 11, 8, 0]))
end

@testset "Misc methods" begin
    vs = [[(4, 1), ()],
    [(0, 11), (11, 12)],
    [(7, 9, 51, 7), (51, 9, 9, 9, 9)],
    [(5, 3, 1, 9), (3, 5, 1, 9, 9, 38, 41)],
    ]
    for F in [union, intersect, symdiff, setdiff]
        for (v1, v2) in vs
            @test F(Set{Int}(v1), Set{Int}(v2)) == Set(F(DigitSet(v1), DigitSet(v2)))
            @test F(Set{Int}(v2), Set{Int}(v1)) == Set(F(DigitSet(v2), DigitSet(v1)))

            @test F(DigitSet(v1), Set(v2)) == DigitSet(F(Set(v1), Set(v2)))
            @test F(DigitSet(v2), Set(v1)) == DigitSet(F(Set(v2), Set(v1)))
        end
    end
    for (v1, v2) in vs
        for F in [⊊, issubset]
            @test F(Set{Int}(v1), Set{Int}(v2)) == F(DigitSet(v1), DigitSet(v2))
            @test F(Set{Int}(v2), Set{Int}(v1)) == F(DigitSet(v2), DigitSet(v1))
        end
        @test allunique(DigitSet(v1))
        @test allunique(DigitSet(v2))
    end

    @test_throws ArgumentError union(DigitSet([1,2]), [-3, 1])
    @test_throws ArgumentError union(DigitSet([55, 51]), [1, 3], [66, 2])
    @test_throws ArgumentError symdiff(DigitSet([1,2]), [61, 99])
    @test_throws ArgumentError symdiff(DigitSet([55, 51]), [1, 3], [55, -1])

    @test intersect(DigitSet([3, 9, 11, 22]), [66, -2, 9, 3], [9]) == DigitSet([9])
    @test intersect(DigitSet([3, 9, 11, 22]), [66, -2, 3], [9]) == DigitSet([])

    @test setdiff(DigitSet([1, 8, 44, 31]), [2, 6, 9, 11], [8]) == DigitSet([1, 44, 31])
    @test setdiff(DigitSet([1, 8, 44, 31]), [2, 6, 9, 11], [9]) == DigitSet([1, 44, 31, 8])

    @test !(DigitSet([1, 2]) ⊊ DigitSet([1, 2]))
    @test !(DigitSet([]) ⊊ DigitSet([]))
    @test (DigitSet([5,3,1]) ⊊ DigitSet([5,3,2,1]))
    @test !(DigitSet([9,3,1]) ⊊ DigitSet([1,3]))
end
