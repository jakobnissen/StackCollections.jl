@testset "Construction" failfast = true begin
    v = UVec{UInt32}()
    @test v isa UVec{UInt32}
    @test isempty(v)
    @test length(v) == 0
    @test size(v) == (0,)
    @test collect(v) == Bool[]

    # Integers are one-element iterables, not raw backing storage.
    @test UVec{UInt8}(1) === UVec{UInt8}([true])
    @test UVec{UInt8}(0) === UVec{UInt8}([false])
    @test UVec{UInt16}(i for i in (1, 0, 1, 1)) === UVec{UInt16}([true, false, true, true])
    @test UVec{UInt16}((UInt8(1), Int16(0), UInt128(1), 0.0)) ===
        UVec{UInt16}([true, false, true, false])
    @test UVec{UInt8}(()) === UVec{UInt8}()

    # Conversion between backing widths depends on length, even when all
    # elements are false and their data bits would fit in the smaller type.
    @test UVec{UInt8}(UVec{UInt16}([1, 0, 1])) === UVec{UInt8}([1, 0, 1])
    @test UVec{UInt16}(UVec{UInt8}([1, 0, 1])) === UVec{UInt16}([1, 0, 1])
    @test UVec{UInt8}(UVec{UInt16}()) === UVec{UInt8}()
    @test_throws ArgumentError UVec{UInt8}(UVec{UInt16}(falses(6)))

    for (T, n) in ((UInt8, 5), (UInt16, 12), (UInt32, 27), (UInt64, 58), (UInt128, 121), (UInt256, 248), (UInt512, 503))
        @test capacity(UVec{T}) === n
        @test isbitstype(UVec{T})
        @test sizeof(UVec{T}) == sizeof(T)
        for b in (false, true)
            full = UVec{T}(fill(b, n))
            @test full isa UVec{T}
            @test collect(full) == fill(b, n)
            @test length(full) == n
            @test !isempty(full)
            @test_throws ArgumentError UVec{T}(fill(b, n + 1))
            @test_throws ArgumentError UVec{T}(b for _ in 1:(n + 1))
        end
    end

    @test_throws MethodError UVec()
    @test_throws MethodError UVec([true])
    @test_throws TypeError UVec{Int}()
    @test_throws TypeError UVec{BigInt}()
    @test_throws InexactError UVec{UInt8}([2])
    @test_throws InexactError UVec{UInt8}([-1])
    @test_throws InexactError UVec{UInt8}([0.5])
    @test_throws MethodError UVec{UInt8}([:invalid])
end

@testset "Basic operations" begin
    v = UVec{UInt8}([1, 0, 1, 1])

    @testset "Equality" begin
        @test v == UVec{UInt16}([1, 0, 1, 1])
        @test v == Bool[1, 0, 1, 1]
        @test v == [1, 0, 1, 1]
        @test v != UVec{UInt8}([1, 1, 0, 1])
        @test v != UVec{UInt8}([1, 0, 1])
        @test UVec{UInt8}() == UVec{UInt128}()
        @test UVec{UInt8}([false]) != UVec{UInt8}()
    end

    @testset "Iteration and indexing" failfast = true begin
        @test IndexStyle(typeof(v)) === IndexLinear()
        @test eachindex(v) == 1:4
        @test eltype(v) === Bool
        @test collect(v) == Bool[1, 0, 1, 1]
        @test length(v) === 4
        @test size(v) === (4,)
        @test size(v, 1) == 4
        @test size(v, 2) == 1
        @test !isempty(v)
        @test !isempty(UVec{UInt8}([false]))
        @test first(v) === true
        @test last(v) === true
        @test v[1] === true
        @test v[2] === false
        @test v[end] === true

        # Integer indices must be checked before narrowing them to Int.
        for T in (Int8, UInt8, Int128, UInt128, BigInt)
            @test v[T(1)] === true
            @test v[T(2)] === false
            @test_throws BoundsError v[T(0)]
            @test_throws BoundsError v[T(5)]
        end
        for i in (-1, typemin(Int), typemax(Int), typemax(UInt128), big(2)^128 + 1)
            @test_throws BoundsError v[i]
        end
        @test_throws BoundsError UVec{UInt8}()[1]
    end

    @testset "copy and empty" failfast = true begin
        for U in (UInt8, UInt16, UInt32, UInt64, UInt128)
            T = UVec{U}
            for data in (Bool[], [false], [true], isodd.(1:capacity(T)))
                original = T(data)
                @test copy(original) === original
                @test empty(original) === T()
                @test IndexStyle(T) === IndexLinear()
            end
        end
    end

    @testset "Range indexing" failfast = true begin
        @test v[1:end] === v
        @test v[1:2] === UVec{UInt8}([1, 0])
        @test v[2:3] === UVec{UInt8}([0, 1])
        @test v[2:end] === UVec{UInt8}([0, 1, 1])
        @test v[1:1] === UVec{UInt8}([true])
        @test v[2:2] === UVec{UInt8}([false])
        @test v[end:end] === UVec{UInt8}([true])
        @test v === UVec{UInt8}([1, 0, 1, 1])

        # Empty ranges select no elements, including ranges with endpoints
        # outside the vector and slices of an empty vector.
        for idx in (1:0, 3:2, 5:4, -2:-3, 20:19)
            @test v[idx] === UVec{UInt8}()
            @test UVec{UInt8}()[idx] === UVec{UInt8}()
        end

        for T in (Int8, UInt8, Int128, UInt128, BigInt)
            @test v[T(2):T(3)] === UVec{UInt8}([0, 1])
            @test v[T(1):T(4)] === v
            @test v[T(2):T(1)] === UVec{UInt8}()
            @test_throws BoundsError v[T(0):T(2)]
            @test_throws BoundsError v[T(3):T(5)]
            @test_throws BoundsError v[T(5):T(5)]
        end

        # Out-of-bounds endpoints must be rejected before truncation to
        # UInt32, even if their low bits would form a valid slice.
        for idx in (
                -1:2, typemin(Int):1, 1:typemax(Int),
                UInt128(1):typemax(UInt128),
                (big(2)^32 + 1):(big(2)^32 + 3),
                (-big(2)^128 + 1):(-big(2)^128 + 3),
            )
            @test_throws BoundsError v[idx]
        end
        @test_throws BoundsError UVec{UInt8}()[1:1]
    end

    @testset "Colon indexing" begin
        @test v[:] === v
        @test UVec{UInt8}()[:] === UVec{UInt8}()
        @test UVec{UInt8}([false])[:] === UVec{UInt8}([false])
    end
end

@testset "Immutable operations" begin
    v = UVec{UInt8}([1, 0, 1])

    @testset "@inbounds" begin
        # Eliding bounds/capacity checks must preserve valid operations and
        # must not elide element conversion checks.
        @test (@inbounds UVec{UInt8}([1, 0, 1])) === v
        @test (@inbounds v[2]) === false
        @test (@inbounds v[2:3]) === UVec{UInt8}([0, 1])
        @test (@inbounds v[1:0]) === UVec{UInt8}()
        @test (@inbounds v[:]) === v
        @test (@inbounds push(v, 0)) === UVec{UInt8}([1, 0, 1, 0])
        @test (@inbounds push(v, 0, 1)) === UVec{UInt8}([1, 0, 1, 0, 1])
        @test (@inbounds pushfirst(v, 0)) === UVec{UInt8}([0, 1, 0, 1])
        @test (@inbounds append(v, (0, 1))) === UVec{UInt8}([1, 0, 1, 0, 1])
        @test (@inbounds pop(v)) === (UVec{UInt8}([1, 0]), true)
        @test (@inbounds popfirst(v)) === (UVec{UInt8}([0, 1]), true)
        @test (@inbounds setindex(v, 1, 2)) === UVec{UInt8}([1, 1, 1])
        @test_throws InexactError @inbounds UVec{UInt8}([2])
        @test_throws InexactError @inbounds push(v, 2)
        @test_throws InexactError @inbounds push(v, 0, 2)
        @test_throws InexactError @inbounds pushfirst(v, 2)
        @test_throws InexactError @inbounds append(v, (0, 2))
        @test_throws InexactError @inbounds setindex(v, 2, 1)
    end

    @testset "push" begin
        pushed = push(v, false)
        @test pushed === UVec{UInt8}([1, 0, 1, 0])
        @test v === UVec{UInt8}([1, 0, 1])
        @test push(v, 0, 1.0) === UVec{UInt8}([1, 0, 1, 0, 1])
        @test push(UVec{UInt8}(), 0, 1, 0, 1, 0) === UVec{UInt8}([0, 1, 0, 1, 0])
        @test push(UVec{UInt8}(), 0) === UVec{UInt8}([false])
        @test_throws ArgumentError push(UVec{UInt8}(falses(5)), false)
        @test_throws ArgumentError push(v, 0, 1, 0)
        @test_throws InexactError push(v, 2)
        @test_throws InexactError push(v, 0, -1)
        @test_throws MethodError push(v, :invalid)
    end

    @testset "pushfirst" begin
        pushed = pushfirst(v, false)
        @test pushed === UVec{UInt8}([0, 1, 0, 1])
        @test v === UVec{UInt8}([1, 0, 1])
        @test pushfirst(v, 1.0) === UVec{UInt8}([1, 1, 0, 1])
        @test pushfirst(UVec{UInt8}(), 0) === UVec{UInt8}([false])
        @test_throws ArgumentError pushfirst(UVec{UInt8}(falses(5)), false)
        @test_throws InexactError pushfirst(v, 2)
        @test_throws MethodError pushfirst(v, :invalid)

        @test pushfirst(v, 0, 1.0) === UVec{UInt8}([0, 1, 1, 0, 1])
        @test pushfirst(UVec{UInt8}(), 0, 1, 0, 1, 0) === UVec{UInt8}([0, 1, 0, 1, 0])
        @test_throws ArgumentError pushfirst(UVec{UInt8}(falses(5)), false, true)
        @test_throws InexactError pushfirst(v, 2, false)
        @test_throws MethodError pushfirst(v, false, :invalid)
        @test_throws InexactError @inbounds pushfirst(v, false, 2)
    end

    @testset "append" begin
        appended = append(v, [0, 1])
        @test appended === UVec{UInt8}([1, 0, 1, 0, 1])
        @test v === UVec{UInt8}([1, 0, 1])
        @test append(v, (0, 1.0)) === appended
        @test append(v, (i for i in (0, 1))) === appended
        @test append(v, UVec{UInt16}([0, 1])) === appended
        @test append(v, 0) === UVec{UInt8}([1, 0, 1, 0])
        @test append(UVec{UInt8}(), v) === v
        @test append(v, ()) === v
        @test append(appended, ()) === appended
        @test_throws ArgumentError append(appended, (0,))
        @test_throws ArgumentError append(v, (0, 1, 0))
        @test_throws InexactError append(v, (0, 2))
        @test_throws MethodError append(v, (:invalid,))
    end

    @testset "pop" begin
        remaining, element = pop(v)
        @test remaining === UVec{UInt8}([1, 0])
        @test element === true
        @test v === UVec{UInt8}([1, 0, 1])
        @test pop(remaining) === (UVec{UInt8}([1]), false)
        @test pop(UVec{UInt8}([true])) === (UVec{UInt8}(), true)
        @test pop(UVec{UInt8}([false])) === (UVec{UInt8}(), false)
        @test_throws ArgumentError pop(UVec{UInt8}())
    end

    @testset "popfirst" begin
        remaining, element = popfirst(v)
        @test remaining === UVec{UInt8}([0, 1])
        @test element === true
        @test v === UVec{UInt8}([1, 0, 1])
        @test popfirst(remaining) === (UVec{UInt8}([1]), false)
        @test popfirst(UVec{UInt8}([true])) === (UVec{UInt8}(), true)
        @test popfirst(UVec{UInt8}([false])) === (UVec{UInt8}(), false)
        @test_throws ArgumentError popfirst(UVec{UInt8}())
    end

    @testset "setindex" failfast = true begin
        @test setindex(v, 0, 1) === UVec{UInt8}([0, 0, 1])
        @test setindex(v, 1.0, 2) === UVec{UInt8}([1, 1, 1])
        @test setindex(v, 0, 3) === UVec{UInt8}([1, 0, 0])
        @test setindex(v, true, 1) === v
        @test v === UVec{UInt8}([1, 0, 1])
        for T in (Int8, UInt8, Int128, UInt128, BigInt)
            @test setindex(v, 1, T(2)) === UVec{UInt8}([1, 1, 1])
            @test_throws BoundsError setindex(v, 0, T(0))
            @test_throws BoundsError setindex(v, 0, T(4))
        end
        for i in (-1, typemin(Int), typemax(Int), typemax(UInt128), big(2)^128 + 1)
            @test_throws BoundsError setindex(v, false, i)
        end
        @test_throws BoundsError setindex(UVec{UInt8}(), true, 1)
        @test_throws InexactError setindex(v, 2, 1)
        @test_throws BoundsError setindex(v, 2, 0)
        @test_throws MethodError setindex(v, :invalid, 1)
    end

    @testset "Vector setindex" failfast = true begin
        for items in ([0, 1], (0, 1), UVec{UInt16}([0, 1]), (i for i in (0, 1)))
            @test setindex(v, items, [3, 2]) === UVec{UInt8}([1, 1, 0])
            @test setindex(v, items, 3:-1:2) === UVec{UInt8}([1, 1, 0])
        end
        @test setindex(v, (0, 1), 1:2) === UVec{UInt8}([0, 1, 1])
        @test setindex(v, [1, 0], [2, 2]) === v
        @test setindex(v, [0, 1], [2, 2]) === UVec{UInt8}([1, 1, 1])
        @test setindex(v, Bool[], Int[]) === v
        @test setindex(UVec{UInt8}(), (), Int[]) === UVec{UInt8}()
        @test setindex(v, view([0, 1], :), view([3, 2], :)) === UVec{UInt8}([1, 1, 0])
        for I in (Int8, UInt8, Int128, UInt128, BigInt)
            @test setindex(v, [0, 1], I[3, 2]) === UVec{UInt8}([1, 1, 0])
        end
        for i in (0, -1, 4, typemin(Int), typemax(UInt128), big(2)^128 + 1)
            @test_throws BoundsError setindex(v, [0], [i])
        end
        @test_throws BoundsError setindex(v, [2], [0])
        @test_throws BoundsError setindex(v, [0], [1, 4])
        @test_throws DimensionMismatch setindex(v, [0], [1, 2])
        @test_throws DimensionMismatch setindex(v, [0, 1], [1])
        @test_throws DimensionMismatch setindex(v, [0], Int[])
        @test_throws InexactError setindex(v, [0, 2], [1, 2])
        @test_throws MethodError setindex(v, [:invalid], [1])
        @test (@inbounds setindex(v, [0, 1], [3, 2])) === UVec{UInt8}([1, 1, 0])
        @test_throws InexactError @inbounds setindex(v, [2], [1])

        # Bool is an Integer subtype, but Boolean vectors are logical masks.
        for mask in (Bool[1, 0, 1], BitVector([1, 0, 1]), UVec{UInt8}([1, 0, 1]))
            @test setindex(v, [0, 0], mask) === UVec{UInt8}([0, 0, 0])
            @test_throws DimensionMismatch setindex(v, [0, 1, 0], mask)
            @test (@inbounds setindex(v, [0, 0], mask)) === UVec{UInt8}([0, 0, 0])
        end
        @test setindex(v, [0, 0, 0], trues(3)) === UVec{UInt8}([0, 0, 0])
        @test setindex(v, (), falses(3)) === v
        @test setindex(UVec{UInt8}(), (), Bool[]) === UVec{UInt8}()
        @test_throws BoundsError setindex(v, (), falses(2))
        @test_throws BoundsError setindex(v, (), falses(4))
        @test v === UVec{UInt8}([1, 0, 1])
    end

    @testset "Range setindex" failfast = true begin
        @test setindex(v, [0, 1], 1:2) === UVec{UInt8}([0, 1, 1])
        @test setindex(v, [1.0, 0.0], 2:3) === UVec{UInt8}([1, 1, 0])
        @test setindex(v, v, 1:3) === v
        for I in (Int8, UInt8, Int128, UInt128, BigInt)
            @test setindex(v, [1, 0], I(2):I(3)) === UVec{UInt8}([1, 1, 0])
            @test_throws BoundsError setindex(v, [0], I(0):I(0))
            @test_throws BoundsError setindex(v, [0], I(4):I(4))
        end
        for r in (1:0, 2:1, 4:3, -2:-3, 20:19)
            @test setindex(v, Bool[], r) === v
            @test setindex(v, UVec{UInt16}(), r) === v
            @test setindex(UVec{UInt8}(), Bool[], r) === UVec{UInt8}()
            @test_throws DimensionMismatch setindex(v, [true], r)
        end
        # Check bounds before computing potentially overflowing range lengths
        # or reporting a mismatch for an invalid selection.
        for r in (
                0:1, 2:4, typemin(Int):0, 0:typemax(Int),
                UInt128(1):typemax(UInt128),
                (big(2)^128 + 1):(big(2)^128 + 3),
            )
            @test_throws BoundsError setindex(v, [0], r)
        end
        @test_throws BoundsError setindex(UVec{UInt8}(), [true], 1:1)
        @test_throws DimensionMismatch setindex(v, [0], 1:2)
        @test_throws DimensionMismatch setindex(v, UVec{UInt16}([0, 1]), 1:1)
        @test_throws InexactError setindex(v, [0, 2], 1:2)
        @test_throws MethodError setindex(v, [:invalid], 1:1)
        @test (@inbounds setindex(v, [0, 1], 1:2)) === UVec{UInt8}([0, 1, 1])
        @test (@inbounds setindex(v, UVec{UInt16}([0, 1]), 1:2)) === UVec{UInt8}([0, 1, 1])
        @test_throws InexactError @inbounds setindex(v, [2], 1:1)
        @test v === UVec{UInt8}([1, 0, 1])
    end
end

@testset "Vector operations" begin
    v = UVec{UInt8}([1, 0, 0, 1, 0])

    @testset "Search indices" failfast = true begin
        for U in (UInt8, UInt16, UInt32, UInt64, UInt128)
            for data in (Bool[], Bool[1, 0, 1, 0])
                searched = UVec{U}(data)
                for f in (identity, !)
                    for I in (Int8, UInt8, Int128, UInt128, BigInt)
                        @test_throws BoundsError findnext(f, searched, I(0))
                        @test findnext(f, searched, I(length(searched) + 1)) === nothing
                        @test findprev(f, searched, I(0)) === nothing
                        @test_throws BoundsError findprev(f, searched, I(length(searched) + 1))
                        for i in eachindex(data)
                            @test findnext(f, searched, I(i)) === findnext(f, data, i)
                            @test findprev(f, searched, I(i)) === findprev(f, data, i)
                            @test (@inbounds findnext(f, searched, I(i))) === findnext(f, data, i)
                            @test (@inbounds findprev(f, searched, I(i))) === findprev(f, data, i)
                        end
                    end
                    # Check before narrowing: these values can wrap to valid indices.
                    for i in (-1, typemin(Int), typemin(Int128), -big(2)^128 + 1)
                        @test_throws BoundsError findnext(f, searched, i)
                        @test findprev(f, searched, i) === nothing
                    end
                    for i in (
                            typemax(Int), typemax(UInt128),
                            UInt128(typemax(UInt)) + 2, big(2)^128 + 1,
                        )
                        @test findnext(f, searched, i) === nothing
                        @test_throws BoundsError findprev(f, searched, i)
                    end
                end
            end
        end
    end

    @testset "sum" begin
        @test sum(v) === 2
        @test sum(UVec{UInt8}()) === 0
        @test sum(UVec{UInt8}(falses(5))) === 0
        @test sum(UVec{UInt8}(trues(5))) === 5
    end

    @testset "reverse" begin
        @test reverse(v) === UVec{UInt8}([0, 1, 0, 0, 1])
        @test v === UVec{UInt8}([1, 0, 0, 1, 0])
        @test reverse(UVec{UInt8}()) === UVec{UInt8}()
        @test reverse(UVec{UInt8}([false])) === UVec{UInt8}([false])
        @test reverse(UVec{UInt8}([true])) === UVec{UInt8}([true])
        @test reverse(v, 2, 4) === UVec{UInt8}([1, 1, 0, 0, 0])
        @test reverse(v, 1, length(v)) === reverse(v)
        @test reverse(v, 3, 3) === v
        @test reverse(v, 4, 2) === v
        @test reverse(UVec{UInt8}(), 1, 0) === UVec{UInt8}()
        @test (@inbounds reverse(v, 2, 4)) === UVec{UInt8}([1, 1, 0, 0, 0])
        @test v === UVec{UInt8}([1, 0, 0, 1, 0])
    end

    @testset "circshift" failfast = true begin
        @test circshift(v, 1) === UVec{UInt8}([0, 1, 0, 0, 1])
        @test circshift(v, -1) === UVec{UInt8}([0, 0, 1, 0, 1])
        @test circshift(v, 0) === v
        @test circshift(v, 5) === v
        @test circshift(v, -10) === v
        @test v === UVec{UInt8}([1, 0, 0, 1, 0])

        # Reduce shifts before narrowing: negative and arbitrarily large
        # integers must wrap by the vector length, not the backing width.
        for i in (
                Int8(-7), UInt8(7), typemin(Int), typemax(Int),
                typemin(Int128), typemax(UInt128), big(2)^150, -big(2)^150,
            )
            shift = Int(mod(i, length(v)))
            @test circshift(v, i) === UVec{UInt8}(circshift(collect(v), shift))
            @test circshift(v, (i,)) === circshift(v, i)
            @test circshift(UVec{UInt8}(), i) === UVec{UInt8}()
            @test circshift(UVec{UInt8}(), (i,)) === UVec{UInt8}()
            @test circshift(UVec{UInt8}([true]), i) === UVec{UInt8}([true])
            @test circshift(UVec{UInt8}([true]), (i,)) === UVec{UInt8}([true])
        end
    end
end

@testset "Backing widths and lengths" failfast = true begin
    # Every UInt8 vector and UInt16 length is covered. Wider types sample
    # lengths around carries, word boundaries, and capacity with patterns
    # that expose high bits and cleared bits.
    # Identity with a freshly constructed result also checks that operations
    # leave no stale bits outside the encoded vector.
    for T in (UInt8, UInt16, UInt32, UInt64, UInt128, UInt256, UInt512)
        @testset "$T" failfast = true begin
            n = capacity(UVec{T})
            # Keep short lengths, both sides of length-field carries, and the
            # point where the payload crosses a 64-bit word after its length field.
            lengths = if T in (UInt256, UInt512)
                filter(<=(n), (0, 1, 127, 128, 129, 255, 256, 257, n - 1, n))
            elseif T in (UInt32, UInt64, UInt128)
                carries = [p + d for p in (4, 8, 16, 32, 64) for d in -1:1]
                boundaries = [64 - (8sizeof(T) - n) + d for d in -1:1]
                sort!(unique(filter(l -> 0 <= l <= n, [0, 1, 2, 3, n ÷ 2, n - 1, n, carries..., boundaries...])))
            else
                0:n
            end
            for len in lengths
                # Keep every UInt8 index. For wider vectors, check both ends,
                # adjacent middle bits, and crossings of backing-word boundaries.
                # Subtract the packed length field to locate those crossings.
                positions = if T === UInt8
                    1:len
                else
                    boundaries = [b - (8sizeof(T) - n) + d for b in (64, 128, 256) for d in -1:1]
                    sort!(unique(filter(i -> 1 <= i <= len, [1, 2, len ÷ 2, len ÷ 2 + 1, len - 1, len, boundaries...])))
                end
                patterns = if T === UInt8
                    ([isodd(bits >> i) for i in 0:(len - 1)] for bits in 0:((1 << len) - 1))
                else
                    (
                        falses(len), trues(len), isodd.(1:len), iseven.(1:len),
                        [i == 1 for i in 1:len], [i == len for i in 1:len],
                    )
                end
                for data in patterns
                    v = UVec{T}(data)
                    @test collect(v) == data
                    @test length(v) === len
                    @test size(v) === (len,)
                    @test isempty(v) == isempty(data)
                    @test v[:] === v
                    @test v[1:len] === v
                    @test sum(v) === sum(data)
                    if isempty(data)
                        @test_throws ArgumentError argmin(v)
                        @test_throws ArgumentError argmax(v)
                    else
                        @test argmin(v) === argmin(data)
                        @test argmax(v) === argmax(data)
                        @test (@inbounds argmin(v)) === argmin(data)
                        @test (@inbounds argmax(v)) === argmax(data)
                    end
                    for f in (identity, !)
                        @test findnext(f, v, len + 1) === nothing
                        @test findprev(f, v, 0) === nothing
                        @test_throws BoundsError findnext(f, v, 0)
                        @test_throws BoundsError findprev(f, v, len + 1)
                        for i in positions
                            @test findnext(f, v, i) === findnext(f, data, i)
                            @test findprev(f, v, i) === findprev(f, data, i)
                        end
                    end
                    # BitIntegers 0.3.7 does not implement bitreverse.
                    @test reverse(v) === UVec{T}(reverse(data)) broken = !hasmethod(bitreverse, Tuple{T})
                    @test reverse(reverse(v)) === v broken = !hasmethod(bitreverse, Tuple{T})
                    for shift in (-len - 1, -1, 0, 1, len, len + 1)
                        @test circshift(v, shift) === UVec{T}(circshift(data, shift))
                    end
                    @test append(v, ()) === v
                    suffix = isodd.(1:(n - len))
                    @test append(v, suffix) === UVec{T}(vcat(data, suffix))
                    for b in (false, true)
                        if len < n
                            @test push(v, b) === UVec{T}(vcat(data, b))
                            @test pushfirst(v, b) === UVec{T}(vcat(b, data))
                            @test pop(push(v, b)) === (v, b)
                            @test popfirst(pushfirst(v, b)) === (v, b)
                        else
                            @test_throws ArgumentError push(v, b)
                            @test_throws ArgumentError pushfirst(v, b)
                            @test_throws ArgumentError append(v, (b,))
                        end
                    end
                    if isempty(data)
                        @test_throws ArgumentError pop(v)
                        @test_throws ArgumentError popfirst(v)
                    else
                        @test pop(v) === (UVec{T}(data[1:(end - 1)]), data[end])
                        @test popfirst(v) === (UVec{T}(data[2:end]), data[1])
                    end
                    for i in positions
                        @test v[i] === data[i]
                        @test v[1:i] === UVec{T}(data[1:i])
                        @test v[i:len] === UVec{T}(data[i:len])
                        @test v[i:i] === UVec{T}(data[i:i])
                        if T === UInt8
                            for j in (i + 1):(len - 1)
                                @test v[i:j] === UVec{T}(data[i:j])
                            end
                        end
                        changed = copy(data)
                        changed[i] = !data[i]
                        @test setindex(v, !data[i], i) === UVec{T}(changed)
                    end
                end
            end
        end
    end
end
