@testset "Construction" begin
    @test StackSet() == StackSet()
    @test StackSet([1, 3, 2]) == StackSet([1,2,3])

    @test length(StackSet([101, 115, 151, 103, 115])) == 4
    @test length(StackSet([-50, -10, -1, -60, -5, -50])) == 5
    @test_throws ArgumentError StackSet([-10, 60])
    @test_throws ArgumentError StackSet([1001, 1070])

    # Equality between when converting to Set
    @test Set(StackSet([501, 515, 540])) == Set(StackSet([540, 515, 501]))
end

@testset "Basic" begin
    @test empty(StackSet([900, 941])) == StackSet()
    @test !isempty(StackSet([0]))
    @test isempty(StackSet([]))
    @test isempty(StackSet())
    @test length(StackSet()) == 0
    @test length(empty(StackSet())) == 0
end

@testset "Iteration" begin
    s = StackSet([577])
    v, st = iterate(s)
    @test v == 577
    @test iterate(s, st) === nothing

    @test Set([i for i in StackSet([-30, 11, 0, 1])]) == Set([1, 0, 11, -30])
end

const vectors = [
[0],
[-5, 6],
[-401, -350, -401],
collect(-4:50),
[503913, 503889, 503936],
]

@testset "Misc" begin
    @test_throws ArgumentError maximum(StackSet())
    @test_throws ArgumentError minimum(StackSet())
    for v in vectors
        @test maximum(StackSet(v)) == maximum(Set(v))
        @test minimum(StackSet(v)) == minimum(Set(v))
        @test first(iterate(v)) in StackSet(v)
        @test !(555 in StackSet(v))
    end
end

@testset "Filter" begin
    for F in [isodd, iseven, x -> true, x -> false, isequal(6)]
        for v in vectors
            @test Set(filter(F, StackSet(v))) == filter(F, Set(v))
        end
    end
end

@testset "Push" begin
    @test push(empty(StackSet()), 99) == StackSet([99])
    @test first(push(StackSet(), -501)) == -501
    for v in vectors
        s = StackSet(v)
        s´ = Set(v)
        for i in [0, -5, 11, 503889, 10040342, -9]
            if max(maximum(s), i) - min(minimum(s), i) > 63
                @test_throws ArgumentError s2 = push(s, i)
            else
                @test Set(push(s, i)) == push!(copy(s´), i)
            end
        end
    end
end

@testset "Pop & Delete" begin
    @test_throws KeyError pop(StackSet(), 0)
    @test_throws KeyError pop(StackSet([-9, 9]), 8)
    @test delete(StackSet(), 0) == StackSet()
    @test delete(StackSet([-9, 9]), 8) == StackSet([-9, 9])
    @test pop(StackSet([19, 8, 22]), 8) == StackSet([19, 22])

    for v in vectors
        s = StackSet(v)
        s´ = Set(v)
        for i in [0, -5, 11, 503889, 10040342, -9]
            if i in s
                s2´ = copy(s´)
                pop!(s2´, i)
                @test Set(pop(s, i)) == s2´
                @test Set(delete(s, i)) == delete!(copy(s´), i)
            else
                @test_throws KeyError pop(s, i)
                @test delete(s, i) == s
            end
        end
    end
end

@testset "Misc methods" begin
    vs = [[(4, 1), ()],
    [(0, 11), (11, 12)],
    [(7, 9, 51, 7), (51, 9, 9, 9, 9)],
    [(5, 3, 1, 9), (3, 5, 1, 9, 9, 38, 41)],
    [(-101, -71), (-71, -105, -89)],
    [(0, 9, -5), (1, -10, 19)],
    ]

    for F in [union, intersect, symdiff, setdiff]
        for (v1, v2) in vs
            @test F(Set{Int}(v1), Set{Int}(v2)) == Set(F(StackSet(v1), StackSet(v2)))
            @test F(Set{Int}(v2), Set{Int}(v1)) == Set(F(StackSet(v2), StackSet(v1)))

            @test F(StackSet(v1), Set(v2)) == StackSet(F(Set(v1), Set(v2)))
            @test F(StackSet(v2), Set(v1)) == StackSet(F(Set(v2), Set(v1)))
        end
    end
    for (v1, v2) in vs
        for F in [⊊, issubset]
            @test F(Set{Int}(v1), Set{Int}(v2)) == F(StackSet(v1), StackSet(v2))
            @test F(Set{Int}(v2), Set{Int}(v1)) == F(StackSet(v2), StackSet(v1))
        end
        @test allunique(StackSet(v1))
        @test allunique(StackSet(v2))
    end

    for (v1, v2) in vs
        @test issubset(Set{Int}(v1), Set{Int}(v2)) == issubset(StackSet(v1), StackSet(v2))
        @test issubset(Set{Int}(v2), Set{Int}(v1)) == issubset(StackSet(v2), StackSet(v1))
    end
end

@testset "Convert to/from DigitSet" begin
    for bad in [(-1,), (44, 10, -3), (55, 65), (101, 102, 103)]
        s = StackSet(bad)
        @test_throws ArgumentError DigitSet(s)
    end
    for good in [(0, 1, 2, 3), 14:21, 1:4:60, (61, 62, 1, 9), (), (0,)]
        s = StackSet(good)
        d = DigitSet(good)
        @test s == d
        @test collect(s) == collect(d)

        s2 = StackSet(d)
        d2 = DigitSet(s)
        @test s == d == s2 == d2
        @test collect(s) == collect(s2) == collect(d2)
    end

    @test DigitSet([1,2,39]) != StackSet([1, 2, 40])
    @test DigitSet([0,1,2]) != StackSet([5,6,7])
end
