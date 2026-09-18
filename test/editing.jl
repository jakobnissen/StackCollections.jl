@testset "Editing and conversion across backing widths" begin
    for U in (UInt8, UInt16, UInt32, UInt64, UInt128)
        @testset "$U" begin
            T = UVec{U}
            cap = capacity(T)
            # Exhaust UInt8, but sample lengths and edit positions for wider
            # types so range operations do not multiply into millions of tests.
            lengths = U === UInt8 ? (0:cap) : (0, 1, 2, cap ÷ 2, cap - 1, cap)
            for len in lengths
                patterns = if U === UInt8
                    ([isodd(bits >> i) for i in 0:(len - 1)] for bits in 0:((1 << len) - 1))
                else
                    (
                        falses(len), trues(len), isodd.(1:len), iseven.(1:len),
                        [i == 1 for i in 1:len], [i == len for i in 1:len],
                    )
                end
                for data in patterns
                    v = T(data)
                    # Identity with freshly constructed values catches stale bits
                    # outside the elements as well as corrupt length fields.
                    for D in (UInt8, UInt16, UInt32, UInt64, UInt128)
                        if len <= capacity(UVec{D})
                            expected = UVec{D}(data)
                            @test UVec{D}(v) === expected
                            @test convert(UVec{D}, v) === expected
                        else
                            @test_throws ArgumentError UVec{D}(v)
                            @test_throws ArgumentError convert(UVec{D}, v)
                        end
                    end
                    positions = unique((1, 1 + len ÷ 2, len + 1))
                    for i in positions, b in (false, true)
                        if len < cap
                            @test insert(v, i, b) === T(insert!(copy(data), i, b))
                        else
                            @test_throws ArgumentError insert(v, i, b)
                        end
                    end
                    positions = isempty(data) ? () : unique((1, 1 + len ÷ 2, len))
                    for i in positions
                        @test deleteat(v, i) === T(deleteat!(copy(data), i))
                        for j in unique((i, i + (len - i) ÷ 2, len))
                            @test deleteat(v, i:j) === T(deleteat!(copy(data), i:j))
                            # Includes positive, zero and negative reversal offsets.
                            @test reverse(v, i, j) === T(reverse(data, i, j))
                        end
                    end
                    @test deleteat(v, 1:len) === T()
                    for n in 2:min(4, cap - len), bits in 0:((1 << n) - 1)
                        prefix = [isodd(bits >> i) for i in 0:(n - 1)]
                        @test pushfirst(v, prefix...) === T(vcat(prefix, data))
                    end
                    for shift in (-len - 1, -1, 0, 1, len + 1)
                        @test circshift(v, (shift,)) === T(circshift(data, shift))
                    end
                end
            end
        end
    end
end

@testset "Vector replacement across backing widths" begin
    for U in (UInt8, UInt16, UInt32, UInt64, UInt128)
        for len in (1, capacity(UVec{U}) ÷ 2, capacity(UVec{U}))
            for data in (trues(len), falses(len), isodd.(1:len))
                v = UVec{U}(data)
                # Unsorted and duplicate indices, including the highest bit.
                indices = [len, 1, len]
                items = Bool[1, 1, 0]
                expected = copy(data)
                expected[indices] = items
                @test Base.setindex(v, items, indices) === UVec{U}(expected)
                mask = isodd.(1:len)
                items = .!data[mask]
                expected = copy(data)
                expected[mask] = items
                @test Base.setindex(v, items, mask) === UVec{U}(expected)
            end
        end
    end
end

@testset "Range replacement across backing widths" begin
    for D in (UInt8, UInt16, UInt32, UInt64, UInt128), S in (UInt8, UInt16, UInt32, UInt64, UInt128)
        for len in (capacity(UVec{D}) ÷ 2, capacity(UVec{D}))
            limit = min(len, capacity(UVec{S}))
            for n in unique((1, limit ÷ 2, limit))
                for start in unique((1, 1 + (len - n) ÷ 2, len - n + 1))
                    r = start:(start + n - 1)
                    for data in (trues(len), isodd.(1:len)), items in (falses(n), trues(n), iseven.(1:n))
                        v = UVec{D}(data)
                        expected = copy(data)
                        expected[r] = items
                        result = UVec{D}(expected)
                        @test Base.setindex(v, items, r) === result
                        @test Base.setindex(v, view(items, :), r) === result
                        @test Base.setindex(v, UVec{S}(items), r) === result
                    end
                end
            end
        end
    end
end

@testset "Conversion capacity boundaries" begin
    for S in (UInt8, UInt16, UInt32, UInt64, UInt128), D in (UInt8, UInt16, UInt32, UInt64, UInt128)
        len = min(capacity(UVec{S}), capacity(UVec{D}))
        # A set high bit must survive widening and narrowing at capacity.
        data = isodd.(1:len)
        data[end] = true
        v = UVec{S}(data)
        @test UVec{D}(v) === UVec{D}(data)
        @test convert(UVec{D}, v) === UVec{D}(data)
        @test UVec{S}(v) === v
        if capacity(UVec{S}) > capacity(UVec{D})
            # Length alone makes this too large, even with no set data bits.
            v = UVec{S}(falses(len + 1))
            @test_throws ArgumentError UVec{D}(v)
            @test_throws ArgumentError convert(UVec{D}, v)
        end
    end
end

@testset "Editing boundaries and integer indices" begin
    v = UVec{UInt8}([1, 0, 1])
    @test insert(UVec{UInt8}(), 1, 1.0) === UVec{UInt8}([true])
    @test insert(v, 1, 0) === UVec{UInt8}([0, 1, 0, 1])
    @test insert(v, 4, 0.0) === UVec{UInt8}([1, 0, 1, 0])
    @test deleteat(UVec{UInt8}([true]), 1) === UVec{UInt8}()
    @test deleteat(UVec{UInt8}([false]), 1:1) === UVec{UInt8}()
    for I in (Int8, UInt8, Int128, UInt128, BigInt)
        @test insert(v, I(2), false) === UVec{UInt8}([1, 0, 0, 1])
        @test deleteat(v, I(2)) === UVec{UInt8}([1, 1])
        @test deleteat(v, I(2):I(3)) === UVec{UInt8}([1])
        @test reverse(v, I(1), I(2)) === UVec{UInt8}([0, 1, 1])
    end
    for i in (-1, 0, 5, typemax(UInt128), big(2)^128 + 1)
        @test_throws BoundsError insert(v, i, false)
        @test_throws BoundsError deleteat(v, i)
        @test_throws BoundsError deleteat(v, i:i)
    end
    for r in (-1:2, 0:1, 2:4, 1:typemax(UInt128), (big(2)^32 + 1):(big(2)^32 + 3))
        @test_throws BoundsError deleteat(v, r)
        @test_throws BoundsError reverse(v, first(r), last(r))
    end
    for r in (1:0, 2:1, 4:3, -2:-3, 20:19)
        @test deleteat(v, r) === v
        @test deleteat(UVec{UInt8}(), r) === UVec{UInt8}()
    end
    @test_throws BoundsError deleteat(UVec{UInt8}(), 1)
    @test_throws BoundsError deleteat(UVec{UInt8}(), 1:1)
    @test_throws BoundsError insert(UVec{UInt8}(), 2, false)
    @test_throws BoundsError deleteat(v, 4)
    @test_throws BoundsError insert(v, 0, 2)
    @test_throws InexactError insert(v, 2, 2)
    @test_throws MethodError insert(v, 2, :invalid)
    @test_throws InexactError pushfirst(v, false, 2)
    @test_throws ArgumentError pushfirst(v, false, true, false)
    @test (@inbounds deleteat(v, 2)) === UVec{UInt8}([1, 1])
    @test (@inbounds deleteat(v, 1:3)) === UVec{UInt8}()
    @test (@inbounds insert(v, 2, false)) === UVec{UInt8}([1, 0, 0, 1])
    @test (@inbounds pushfirst(v, false, true)) === UVec{UInt8}([0, 1, 1, 0, 1])
    @test (@inbounds UVec{UInt16}(v)) === UVec{UInt16}([1, 0, 1])
    @test_throws InexactError @inbounds insert(v, 2, 2)
    @test v === UVec{UInt8}([1, 0, 1])
end
