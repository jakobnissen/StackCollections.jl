@testset "Construction" failfast = true begin
    # Empty construction is typed by the backing unsigned integer, and empty
    # preserves that concrete USet type.
    empty_set = USet{UInt32}()
    @test empty_set isa USet{UInt32}
    @test isempty(empty_set)
    @test length(empty_set) == 0
    @test empty(empty_set) === empty_set

    # An integer is treated as a one-element iterable by the constructor.
    single = USet{UInt128}(UInt128(55))
    @test single isa USet{UInt128}
    @test collect(single) == UInt32[55]

    # Lazy iterables use the same generic construction path as arrays and
    # still produce a sorted, duplicate-free set.
    @test USet{UInt16}(i for i in (3, 1, 3, 0)) == USet{UInt16}([0, 1, 3])

    # Exercise the lowest and highest representable bits, including singleton
    # sets used by first/last, pop, and popfirst.
    for T in (UInt8, UInt16, UInt128, UInt256, UInt512)
        max_member = Int(maximum_member(USet{T}))
        low = USet{T}([0])
        high = USet{T}([max_member])
        endpoints = USet{T}([0, max_member])
        @test collect(endpoints) == UInt32[0, max_member]
        @test first(high) === UInt32(max_member)
        @test last(low) === UInt32(0)
        @test pop(high) == (USet{T}(), UInt32(max_member))
        @test popfirst(low) == (USet{T}(), UInt32(0))
        @test_throws ArgumentError USet{T}([max_member + 1])
    end

    # Construction accepts all integer types and removes duplicates while
    # storing elements in sorted order.
    @test USet{UInt16}([UInt8(3), Int16(1), UInt32(3), Int128(7)]) ==
        USet{UInt16}([1, 3, 7])
    @test collect(USet{UInt16}([3, 1, 3, 0])) == UInt32[0, 1, 3]
    # Converting between widths succeeds when every member fits, including
    # widening and conversion of an empty set.
    @test USet{UInt8}(USet{UInt16}([1, 7])) == USet{UInt8}([1, 7])
    @test typeof(USet{UInt16}(USet{UInt8}([1, 7]))) === USet{UInt16}
    @test USet{UInt8}(USet{UInt16}()) == USet{UInt8}()

    # The representable range depends only on the backing integer width, not
    # on the set contents; both type- and value-based queries are supported.
    @test maximum_member(USet{UInt8}) == UInt32(7)
    @test maximum_member(USet{UInt128}) == UInt32(127)
    @test can_contain(USet{UInt8}, 0)
    @test can_contain(USet{UInt8}([7]), 7)
    @test !can_contain(USet{UInt8}(), -1)
    @test !can_contain(USet{UInt8}, 8)

    # A backing type is required, must be unsigned, and all input members must
    # be integers representable by that backing type.
    @test_throws MethodError USet()
    @test_throws MethodError USet([1, 2])
    @test_throws TypeError USet{Int}()
    @test_throws TypeError USet{BigInt}()
    @test_throws ArgumentError USet{UInt8}([-1])
    @test_throws ArgumentError USet{UInt8}([8])
    @test_throws ArgumentError USet{UInt8}(USet{UInt16}([8]))
    @test_throws MethodError USet{UInt8}([:not_an_integer])
end

@testset "Basic operations" begin
    s = USet{UInt8}([7, 0, 3, 1])

    @testset "show" begin
        @test sprint(show, USet{UInt8}()) == "USet{UInt8}([])"
        @test sprint(show, USet{UInt16}([15])) == "USet{UInt16}([15])"
        @test sprint(show, s) == "USet{UInt8}([0, 1, 3, 7])"
        # Exactly twenty members are shown in full; larger sets show the
        # first and last ten members with an ellipsis between them.
        @test sprint(show, USet{UInt32}(0:19)) ==
            "USet{UInt32}([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19])"
        @test sprint(show, USet{UInt32}(0:20)) ==
            "USet{UInt32}([0, 1, 2, 3, 4, 5, 6, 7, 8, 9 … 11, 12, 13, 14, 15, 16, 17, 18, 19, 20])"
        @test sprint(show, USet{UInt128}(0:2:126)) ==
            "USet{UInt128}([0, 2, 4, 6, 8, 10, 12, 14, 16, 18 … 108, 110, 112, 114, 116, 118, 120, 122, 124, 126])"
    end

    @testset "Equality" begin
        # Equality is independent of backing width and works with ordinary
        # sets, while differing members make the sets unequal.
        @test s == USet{UInt8}([0, 1, 3, 7])
        @test s == USet{UInt16}([0, 1, 3, 7])
        @test s == Set{UInt32}([0, 1, 3, 7])
        @test s == Set{Int}([0, 1, 3, 7])
        @test !(s == Set{String}(["0", "1", "3", "7"]))
        @test s != USet{UInt8}([0, 1, 3])
        @test s != Set{UInt32}([0, 1, 3])
    end

    @testset "Iteration and membership" begin
        # Iteration yields sorted UInt32 members; membership handles values
        # outside the representable range without throwing.
        @test collect(s) == UInt32[0, 1, 3, 7]
        @test collect(USet{UInt8}()) == UInt32[]
        @test length(s) == 4
        @test !isempty(s)
        @test isempty(USet{UInt8}())

        @test all(i -> i in s, (0, 1, 3, 7))
        @test all(i -> !(i in s), (-1, 2, 8, 256))
        # checkbounds tests whether an integer is representable as an index,
        # rather than whether that integer is currently a member.
        @test checkbounds(Bool, s, 0)
        @test checkbounds(Bool, s, 7)
        @test !checkbounds(Bool, s, -1)
        @test !checkbounds(Bool, s, 8)
        @test checkbounds(s, 3) === true
        @test_throws BoundsError checkbounds(s, -1)
        @test_throws BoundsError checkbounds(s, 8)
    end

    @testset "Ordering and extrema" begin
        # Since iteration is sorted, the order and extrema methods report the
        # lowest and highest set bits directly.
        @test issorted(s)
        @test first(s) === UInt32(0)
        @test last(s) === UInt32(7)
        @test minimum(s) === UInt32(0)
        @test maximum(s) === UInt32(7)
        @test extrema(s) == (UInt32(0), UInt32(7))

        empty_set = USet{UInt8}()
        @test_throws ArgumentError first(empty_set)
        @test_throws ArgumentError last(empty_set)
        @test_throws ArgumentError minimum(empty_set)
        @test_throws ArgumentError maximum(empty_set)
        @test_throws ArgumentError extrema(empty_set)
    end

    @testset "filter" begin
        # Filtering returns an immutable USet with the same backing type.
        @test filter(iseven, s) == USet{UInt8}([0])
        @test filter(>(2), s) == USet{UInt8}([3, 7])
        @test typeof(filter(iseven, s)) === typeof(s)
    end
end

@testset "Immutable operations" begin
    s = USet{UInt8}([0, 3, 7])

    @testset "@inbounds" begin
        # Valid operations retain their behavior when callers explicitly
        # request elision of the documented bounds/nonempty checks.
        @test (@inbounds push(s, 1)) == USet{UInt8}([0, 1, 3, 7])
        @test (@inbounds pop(s)) == (USet{UInt8}([0, 3]), UInt32(7))
        @test (@inbounds popfirst(s)) == (USet{UInt8}([3, 7]), UInt32(0))
        @test (@inbounds first(s)) === UInt32(0)
        @test (@inbounds last(s)) === UInt32(7)
        @test (@inbounds extrema(s)) == (UInt32(0), UInt32(7))
    end

    @testset "push" begin
        # push is immutable, idempotent for existing members, supports a
        # variadic form, and rejects members outside the backing width.
        pushed = push(s, 1)
        @test pushed == USet{UInt8}([0, 1, 3, 7])
        @test s == USet{UInt8}([0, 3, 7])
        @test typeof(pushed) === typeof(s)
        @test push(s, 3) == s
        @test push(s, 1, 2, 4) == USet{UInt8}([0, 1, 2, 3, 4, 7])
        @test push(s, 1, 2, 4, 6, 7) == USet{UInt8}([0, 1, 2, 3, 4, 6, 7])
        @test_throws ArgumentError push(s, -1)
        @test_throws ArgumentError push(s, 8)
        @test_throws ArgumentError push(s, 1, 8)
    end

    @testset "pop" begin
        # pop removes the greatest member and returns both the new set and the
        # removed UInt32 member without changing the original set.
        remaining, element = pop(s)
        @test remaining == USet{UInt8}([0, 3])
        @test element === UInt32(7)
        @test typeof(remaining) === typeof(s)
        @test_throws ArgumentError pop(USet{UInt8}())
    end

    @testset "popfirst" begin
        # popfirst is the corresponding operation for the least member.
        remaining, element = popfirst(s)
        @test remaining == USet{UInt8}([3, 7])
        @test element === UInt32(0)
        @test typeof(remaining) === typeof(s)
        @test_throws ArgumentError popfirst(USet{UInt8}())
    end

    @testset "pop member" failfast = true begin
        # pop(s, i) is immutable and treats absent or unrepresentable members as
        # no-ops.
        @test pop(s, 3) == USet{UInt8}([0, 7])
        @test pop(s, 4) === s
        @test pop(s, -1) === s
        @test pop(s, 8) === s
        @test pop(s, 0) === USet{UInt8}([3, 7])
        @test pop(s, 7) === USet{UInt8}([0, 3])
        @test pop(USet{UInt8}([7]), 7) === USet{UInt8}()
        @test pop(USet{UInt8}(), 0) === USet{UInt8}()
        for I in (Int8, UInt8, Int128, UInt128, BigInt)
            @test pop(s, I(3)) === USet{UInt8}([0, 7])
        end
        for i in (typemin(Int), typemax(UInt128), big(2)^128 + 3, -big(2)^128 + 3)
            @test pop(s, i) === s
            @test (@inbounds pop(s, i)) === s
        end
        @test s == USet{UInt8}([0, 3, 7])
    end
end

@testset "Set operations" begin
    a = USet{UInt8}([0, 1, 3, 7])
    b = USet{UInt8}([1, 2, 3, 5])
    wide = USet{UInt16}([1, 2, 3, 5])
    wide_with_extra = USet{UInt16}([1, 2, 8])

    @testset "Union" begin
        # Union preserves the type of its first USet, accepts generic
        # iterables, and requires every resulting member to be representable.
        @test union(a) === a
        @test union(a, b) == USet{UInt8}([0, 1, 2, 3, 5, 7])
        @test union(a, wide) == USet{UInt8}([0, 1, 2, 3, 5, 7])
        @test union(wide, a) == USet{UInt16}([0, 1, 2, 3, 5, 7])
        @test typeof(union(a, wide)) === USet{UInt8}
        @test union(a, [2, 5]) == USet{UInt8}([0, 1, 2, 3, 5, 7])
        @test union(a, (2, 5)) == USet{UInt8}([0, 1, 2, 3, 5, 7])
        @test union(a, b, USet{UInt8}([4]), [6]) ==
            USet{UInt8}([0, 1, 2, 3, 4, 5, 6, 7])
        @test_throws ArgumentError union(a, wide_with_extra)
        @test_throws ArgumentError union(a, [8])
    end

    @testset "Intersect" begin
        # Intersection preserves the first USet's type and ignores members
        # that cannot fit in it, including members from generic iterables.
        @test intersect(a) === a
        @test intersect(a, b) == USet{UInt8}([1, 3])
        @test intersect(a, wide) == USet{UInt8}([1, 3])
        @test intersect(wide, a) == USet{UInt16}([1, 3])
        @test intersect(a, [1, 8, 300]) == USet{UInt8}([1])
        @test intersect(a, (1, 3, 8)) == USet{UInt8}([1, 3])
        @test intersect(a, b, USet{UInt8}([1, 3]), [3]) == USet{UInt8}([3])
        @test intersect(a, [8], [0]) == USet{UInt8}()
        @test_throws MethodError intersect(a, [:not_an_integer])
    end

    @testset "Setdiff" begin
        # Set difference also preserves the first USet's type, so different
        # widths work even when the second USet can contain additional values.
        @test setdiff(a) === a
        @test setdiff(a, b) == USet{UInt8}([0, 7])
        @test setdiff(a, wide) == USet{UInt8}([0, 7])
        @test setdiff(a, wide_with_extra) == USet{UInt8}([0, 3, 7])
        @test setdiff(wide, a) == USet{UInt16}([2, 5])
        @test setdiff(wide_with_extra, a) == USet{UInt16}([2, 8])
        # Out-of-range values cannot remove members and are ignored.
        @test setdiff(a, [1, 8, 300]) == USet{UInt8}([0, 3, 7])
        @test setdiff(a, (1, 3, 8)) == USet{UInt8}([0, 7])
        @test setdiff(a, [0, 1, 3, 7, 8]) == USet{UInt8}()
        @test setdiff(a, b, USet{UInt8}([0]), [7]) == USet{UInt8}()
        @test setdiff(a, a, [0]) == USet{UInt8}()
        @test_throws MethodError setdiff(a, [:not_an_integer])
    end

    @testset "Symdiff" begin
        # Symmetric difference follows the first USet's type, but unlike
        # intersection and setdiff it must reject an unrepresentable member.
        @test symdiff(a) === a
        @test symdiff(a, b) == USet{UInt8}([0, 2, 5, 7])
        @test symdiff(a, wide) == USet{UInt8}([0, 2, 5, 7])
        @test symdiff(wide, a) == USet{UInt16}([0, 2, 5, 7])
        @test symdiff(a, [1, 6]) == USet{UInt8}([0, 3, 6, 7])
        @test symdiff(a, (1, 2)) == USet{UInt8}([0, 2, 3, 7])
        @test symdiff(a, b, USet{UInt8}([4]), [6]) ==
            USet{UInt8}([0, 2, 4, 5, 6, 7])
        @test_throws ArgumentError symdiff(a, wide_with_extra)
        @test_throws ArgumentError symdiff(a, [8])
        @test_throws MethodError symdiff(a, [:not_an_integer])
    end

    @testset "Isdisjoint" begin
        # Disjointness compares the represented members across backing widths,
        # and also accepts ordinary iterable/set operands through Base.
        @test isdisjoint(a, USet{UInt8}([2, 4]))
        @test !isdisjoint(a, b)
        @test isdisjoint(a, USet{UInt16}([2, 8]))
        @test isdisjoint(a, Set([8]))
        @test !isdisjoint(a, Set([3]))
    end

    @testset "Issubset" begin
        # Subset checks work for USet pairs and use the generic set fallback
        # when the right-hand operand is an ordinary set.
        @test issubset(USet{UInt8}([1, 3]), a)
        @test !issubset(a, USet{UInt8}([1, 3]))
        @test issubset(USet{UInt8}(), a)
        @test issubset(USet{UInt8}([1, 3]), Set([1, 3, 8]))
    end
end

@testset "Conversion and raw storage" failfast = true begin
    for S in (UInt8, UInt16, UInt32, UInt64, UInt128, UInt256, UInt512)
        for raw in (zero(S), one(S), S(0xa5), typemax(S), one(S) << (8sizeof(S) - 1))
            s = uset_from_integer(raw)
            @test s isa USet{S}
            @test collect(s) == UInt32[i for i in 0:(8sizeof(S) - 1) if isodd(raw >> i)]
            @test Integer(s) === raw
            @test reinterpret(S, s) === raw
            @test uset_from_integer(Integer(s)) === s
            @test copy(s) === s
            @test convert(USet{S}, s) === s
            for D in (UInt8, UInt16, UInt32, UInt64, UInt128, UInt256, UInt512)
                if isempty(s) || maximum(s) < 8sizeof(D)
                    @test convert(USet{D}, s) === USet{D}(collect(s))
                else
                    @test_throws ArgumentError convert(USet{D}, s)
                end
            end
        end
    end
    @test Integer(USet{UInt8}([0, 3, 5])) === 0x29
    @test uset_from_integer(0x05) === USet{UInt8}([0, 2])
    @test_throws MethodError uset_from_integer(5)
end

@testset "Large backing integers" failfast = true begin
    for U in (UInt256, UInt512)
        @testset "$U" failfast = true begin
            top = 8sizeof(U) - 1
            members = [0, 127, 128, 129, top - 1, top]
            reference = Set(members)
            s = USet{U}(members)
            @test collect(s) == UInt32.(members)
            @test length(s) == length(reference)
            @test maximum_member(typeof(s)) == top
            @test extrema(s) == (UInt32(0), UInt32(top))
            for i in (-1, 0, 126, 127, 128, 129, 130, top - 1, top, top + 1)
                @test (i in s) == (i in reference)
            end
            @test push(s, 200) == union(reference, [200])
            @test pop(s, 129) == setdiff(reference, [129])
            remaining, item = pop(s)
            @test remaining == setdiff(reference, [top])
            @test item === UInt32(top)
            high = USet{U}([129, top])
            remaining, item = popfirst(high)
            @test collect(remaining) == UInt32[top]
            @test item === UInt32(129)
            @test filter(>(128), s) == filter(>(128), reference)

            # Compare same-width and mixed-width operations with ordinary sets.
            # The UInt512 operand also has a member that cannot fit in UInt256.
            for V in (UInt256, UInt512)
                others = [127, 129, 200, 8sizeof(V) - 1]
                t = USet{V}(others)
                expected = Set(others)
                for op in (intersect, setdiff)
                    result = op(s, t)
                    @test result isa USet{U}
                    @test result == op(reference, expected)
                end
                for op in (union, symdiff)
                    if maximum(others) <= top
                        result = op(s, t)
                        @test result isa USet{U}
                        @test result == op(reference, expected)
                    else
                        @test_throws ArgumentError op(s, t)
                    end
                end
                @test !isdisjoint(s, t)
                @test isdisjoint(high, USet{V}([128, 200]))
                @test issubset(USet{V}([128, 129]), s)
                @test !issubset(t, s)
            end
        end
    end
end
