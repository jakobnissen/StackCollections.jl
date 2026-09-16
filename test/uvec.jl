@testset "Construction" begin
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

    for (T, n) in ((UInt8, 5), (UInt16, 12), (UInt32, 27), (UInt64, 58), (UInt128, 121))
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

    @testset "Iteration and indexing" begin
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

    @testset "Range indexing" begin
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
        @test (@inbounds Base.setindex(v, 1, 2)) === UVec{UInt8}([1, 1, 1])
        @test_throws InexactError @inbounds UVec{UInt8}([2])
        @test_throws InexactError @inbounds push(v, 2)
        @test_throws InexactError @inbounds push(v, 0, 2)
        @test_throws InexactError @inbounds pushfirst(v, 2)
        @test_throws InexactError @inbounds append(v, (0, 2))
        @test_throws InexactError @inbounds Base.setindex(v, 2, 1)
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

    @testset "setindex" begin
        @test Base.setindex(v, 0, 1) === UVec{UInt8}([0, 0, 1])
        @test Base.setindex(v, 1.0, 2) === UVec{UInt8}([1, 1, 1])
        @test Base.setindex(v, 0, 3) === UVec{UInt8}([1, 0, 0])
        @test Base.setindex(v, true, 1) === v
        @test v === UVec{UInt8}([1, 0, 1])
        for T in (Int8, UInt8, Int128, UInt128, BigInt)
            @test Base.setindex(v, 1, T(2)) === UVec{UInt8}([1, 1, 1])
            @test_throws BoundsError Base.setindex(v, 0, T(0))
            @test_throws BoundsError Base.setindex(v, 0, T(4))
        end
        for i in (-1, typemin(Int), typemax(Int), typemax(UInt128), big(2)^128 + 1)
            @test_throws BoundsError Base.setindex(v, false, i)
        end
        @test_throws BoundsError Base.setindex(UVec{UInt8}(), true, 1)
        @test_throws InexactError Base.setindex(v, 2, 1)
        @test_throws MethodError Base.setindex(v, :invalid, 1)
    end
end

@testset "Vector operations" begin
    v = UVec{UInt8}([1, 0, 0, 1, 0])

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
    end

    @testset "circshift" begin
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
            @test circshift(UVec{UInt8}(), i) === UVec{UInt8}()
            @test circshift(UVec{UInt8}([true]), i) === UVec{UInt8}([true])
        end
    end
end

@testset "Backing widths and lengths" begin
    # Every UInt8 vector is covered. Wider types exercise every length with
    # patterns that expose length-bit carries, high bits, and cleared bits.
    # Identity with a freshly constructed result also checks that operations
    # leave no stale bits outside the encoded vector.
    for T in (UInt8, UInt16, UInt32, UInt64, UInt128)
        @testset "$T" begin
            n = capacity(UVec{T})
            for len in 0:n
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
                    @test reverse(v) === UVec{T}(reverse(data))
                    @test reverse(reverse(v)) === v
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
                    for i in eachindex(data)
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
                        @test Base.setindex(v, !data[i], i) === UVec{T}(changed)
                    end
                end
            end
        end
    end
end
