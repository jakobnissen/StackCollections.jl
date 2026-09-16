@testset "Construction" begin
    # Empty construction
    s = USet{UInt32}()
    @test s isa USet{UInt32}
    @test isempty(s)
    @test s == Set{UInt32}()

    # Constructing from a single integer makes it contain the
    # integer (since integers are iterable it hits the default constructor)
    s = USet{UInt128}(UInt128(55))
    @test length(s) === 1
    @test only(s) === UInt128(55)

    # Construct from iterable of different integer type works
    # TODO

    # Construct from integer type not convertible to UInt32 calls
    # convert(T, i) as expected and throws an exception
    # TODO

    # Construction from iterable with repeated elements is idempotent
    # TODO

    # TODO: Possibly more test cases?

    # No default value of U
    @test_throws USet()
    @test_throws USet([1, 2])

    # Signed integers fails
    @test_throws TypeError USet{Int}()

    # Big integers fails
    @test_throws TypeError USet{BigInt}()
end

@testset "Basic operations" begin
    @testset "Equality" begin
        # USets of different U may be equal

        # USets with incompatible elements do not throw when
        # compared, but compares equal

        # Comparisons with normal Set works
    end

    @testset "Iteration" begin
        # TODO
    end

    @testset "Misc" begin
        # TODO: Add tests for isempty, length, extrema, first, last,
        # minimum, maximum, issorted and other functions that are easily tested

        # which do not fit elsewhere. If the tests become larger than about
        # 25 lines or so, move them to their own testset.
    end
end

@testset "Immutable operations" begin
    @testset "push" begin
        # TODO
    end

    @testset "pop" begin
        # TODO
    end

    @testset "popfirst" begin
        # TODO
    end

    @testset "delete" begin
        # TODO
    end
end

@testset "Set operations" begin
    @testset "Union" begin
        # TODO
    end

    @testset "Intersect" begin
        # TODO
    end

    @testset "Setdiff" begin
        # TODO
    end

    @testset "Symdiff" begin
        # TODO
    end

    @testset "Isdisjoint" begin
        # TODO
    end

    @testset "Issubset" begin
        # TODO
    end
end
