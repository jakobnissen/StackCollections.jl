@testset "Editing and conversion across backing widths" failfast = true begin
    for U in (UInt8, UInt16, UInt32, UInt64, UInt128, UInt256, UInt512)
        @testset "$U" failfast = true begin
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
                    for D in (UInt8, UInt16, UInt32, UInt64, UInt128, UInt256, UInt512)
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
                            # Nontrivial reversal needs bitreverse, which
                            # BitIntegers 0.3.7 does not implement.
                            @test reverse(v, i, j) === T(reverse(data, i, j)) broken = i < j && !hasmethod(bitreverse, Tuple{U})
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

@testset "Vector indexing across backing widths" failfast = true begin
    for U in (UInt8, UInt16, UInt32, UInt64, UInt128, UInt256, UInt512)
        T = UVec{U}
        cap = capacity(T)
        for n in (0, 1, cap ÷ 2, cap - 1, cap)
            for data in (falses(n), trues(n), isodd.(1:n), iseven.(1:n))
                v = T(data)
                for mask in (falses(n), trues(n), isodd.(1:n), iseven.(1:n))
                    expected = T(data[mask])
                    @test v[mask] === expected
                    @test v[T(mask)] === expected
                end
                for idx in (n:-1:1, collect(n:-1:1), 1:2:n)
                    @test v[idx] === T(data[idx])
                end
                if n > 0
                    for idx in ([n, 1, n], fill(n, cap))
                        @test v[idx] === T(data[idx])
                    end
                    @test_throws ArgumentError v[fill(n, cap + 1)]
                end
            end
        end
    end
end

@testset "Vector replacement across backing widths" failfast = true begin
    for U in (UInt8, UInt16, UInt32, UInt64, UInt128, UInt256, UInt512)
        for len in (1, capacity(UVec{U}) ÷ 2, capacity(UVec{U}))
            for data in (trues(len), falses(len), isodd.(1:len))
                v = UVec{U}(data)
                # Unsorted and duplicate indices, including the highest bit.
                indices = [len, 1, len]
                items = Bool[1, 1, 0]
                expected = copy(data)
                expected[indices] = items
                @test setindex(v, items, indices) === UVec{U}(expected)
                mask = isodd.(1:len)
                items = .!data[mask]
                expected = copy(data)
                expected[mask] = items
                @test setindex(v, items, mask) === UVec{U}(expected)
            end
        end
    end
end

@testset "Range replacement across backing widths" failfast = true begin
    for D in (UInt8, UInt16, UInt32, UInt64, UInt128, UInt256, UInt512), S in (UInt8, UInt16, UInt32, UInt64, UInt128, UInt256, UInt512)
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
                        # Vector and view replacements do not depend on S.
                        # Cover them once per destination width; retain every
                        # source/destination pair for packed replacements.
                        if S === D
                            @test setindex(v, items, r) === result
                            @test setindex(v, view(items, :), r) === result
                        end
                        @test setindex(v, UVec{S}(items), r) === result
                    end
                end
            end
        end
    end
end

@testset "spliceinto" failfast = true begin
    @testset "spliceinto exhaustive UInt8 insertions" failfast = true begin
        for n in 0:5, m in 0:(5 - n), a in 0:((1 << n) - 1), b in 0:((1 << m) - 1)
            data = [isodd(a >> j) for j in 0:(n - 1)]
            items = [isodd(b >> j) for j in 0:(m - 1)]
            v = UVec{UInt8}(data)
            for i in 1:(n + 1)
                expected = UVec{UInt8}(vcat(data[1:(i - 1)], items, data[i:end]))
                @test spliceinto(v, i, items) === expected
                @test spliceinto(v, i, UVec{UInt8}(items)) === expected
            end
        end
    end

    @testset "spliceinto across backing widths" failfast = true begin
        for D in (UInt8, UInt16, UInt32, UInt64, UInt128, UInt256, UInt512), S in (UInt8, UInt16, UInt32, UInt64, UInt128, UInt256, UInt512)
            cap = capacity(UVec{D})
            for n in unique((0, 1, cap ÷ 2, cap))
                limit = min(cap - n, capacity(UVec{S}))
                for m in unique((0, 1, limit ÷ 2, limit))
                    m > limit && continue
                    for data in (trues(n), falses(n), isodd.(1:n)), items in (trues(m), falses(m), iseven.(1:m))
                        v = UVec{D}(data)
                        e = UVec{S}(items)
                        for i in unique((1, 1 + n ÷ 2, n + 1))
                            expected = UVec{D}(vcat(data[1:(i - 1)], items, data[i:end]))
                            @test spliceinto(v, i, e) === expected
                            if S === D
                                @test spliceinto(v, i, view(items, :)) === expected
                            end
                        end
                    end
                end
            end
            full = UVec{D}(falses(cap))
            @test_throws ArgumentError spliceinto(full, 1, UVec{S}([false]))
            if capacity(UVec{S}) > cap
                @test_throws ArgumentError spliceinto(UVec{D}(), 1, UVec{S}(falses(cap + 1)))
            end
        end
    end

    @testset "spliceinto boundaries and conversions" failfast = true begin
        v = UVec{UInt8}([1, 0])
        expected = UVec{UInt8}([1, 0, 0])
        @test spliceinto(v, 2, [0.0]) === expected
        @test spliceinto(v, 2, [0, 1.0]) === UVec{UInt8}([1, 0, 1, 0])
        for items in ([false], UVec{UInt8}([false]), UVec{UInt16}([false]))
            for I in (Int8, UInt8, Int128, UInt128, BigInt)
                @test spliceinto(v, I(2), items) === expected
            end
            @test (@inbounds spliceinto(v, 2, items)) === expected
        end
        for items in (Bool[], [false], UVec{UInt8}(), UVec{UInt8}([false]))
            for i in (-1, 0, 4, typemin(Int), typemax(UInt128), big(2)^128 + 1)
                @test_throws BoundsError spliceinto(v, i, items)
            end
            for i in (0, 2)
                @test_throws BoundsError spliceinto(UVec{UInt8}(), i, items)
            end
        end
        @test_throws ArgumentError spliceinto(v, 2, falses(4))
        @test_throws ArgumentError spliceinto(UVec{UInt8}(), 1, falses(6))
        for items in ([2], [-1], [0.5])
            @test_throws InexactError spliceinto(v, 2, items)
            @test_throws InexactError @inbounds spliceinto(v, 2, items)
        end
        @test_throws MethodError spliceinto(v, 2, [:invalid])
        @test v === UVec{UInt8}([1, 0])
    end

    @testset "spliceinto exhaustive UInt8 ranges" failfast = true begin
        cap = capacity(UVec{UInt8})
        for n in 0:cap, a in 0:((1 << n) - 1)
            data = [isodd(a >> j) for j in 0:(n - 1)]
            v = UVec{UInt8}(data)
            for first in 1:(n + 1), last in (first - 1):n
                for m in 0:(cap - n + last - first + 1), b in 0:((1 << m) - 1)
                    items = [isodd(b >> j) for j in 0:(m - 1)]
                    expected = UVec{UInt8}(vcat(data[1:(first - 1)], items, data[(last + 1):end]))
                    @test spliceinto(v, first:last, items) === expected
                    @test spliceinto(v, first:last, UVec{UInt8}(items)) === expected
                end
            end
        end
    end

    @testset "spliceinto ranges across backing widths" failfast = true begin
        for D in (UInt8, UInt16, UInt32, UInt64, UInt128, UInt256, UInt512), S in (UInt8, UInt16, UInt32, UInt64, UInt128, UInt256, UInt512)
            cap = capacity(UVec{D})
            for n in unique((0, 1, cap ÷ 2, cap))
                for first in unique((1, 1 + n ÷ 2, n + 1)), last in unique((first - 1, first - 1 + (n - first + 1) ÷ 2, n))
                    limit = min(cap - n + last - first + 1, capacity(UVec{S}))
                    for m in unique((0, min(1, limit), limit ÷ 2, limit))
                        for data in (trues(n), falses(n), isodd.(1:n)), items in (trues(m), falses(m), iseven.(1:m))
                            v = UVec{D}(data)
                            expected = UVec{D}(vcat(data[1:(first - 1)], items, data[(last + 1):end]))
                            @test spliceinto(v, first:last, UVec{S}(items)) === expected
                            if S === D
                                @test spliceinto(v, first:last, view(items, :)) === expected
                            end
                        end
                    end
                end
            end
            full = UVec{D}(trues(cap))
            @test_throws ArgumentError spliceinto(full, 1:1, UVec{S}([false, true]))
            @test_throws ArgumentError spliceinto(full, (cap + 1):cap, UVec{S}([true]))
        end
    end

    @testset "spliceinto range boundaries and conversions" failfast = true begin
        v = UVec{UInt8}([1, 0, 1])
        expected = UVec{UInt8}([1, 0])
        @test spliceinto(v, 2:3, [0.0]) === expected
        for items in ([false], UVec{UInt8}([false]), UVec{UInt16}([false]))
            for I in (Int8, UInt8, Int128, UInt128, BigInt)
                @test spliceinto(v, I(2):I(3), items) === expected
                @test spliceinto(v, I(4):I(3), items) === UVec{UInt8}([1, 0, 1, 0])
            end
            @test (@inbounds spliceinto(v, 2:3, items)) === expected
        end
        for items in (Bool[], [false], UVec{UInt8}(), UVec{UInt8}([false]))
            for r in (-1:1, 0:0, 2:4, 0:-1, 5:4, 1:typemax(UInt128), (big(2)^128 + 1):(big(2)^128 + 2))
                @test_throws BoundsError spliceinto(v, r, items)
            end
            @test_throws BoundsError spliceinto(UVec{UInt8}(), 1:1, items)
        end
        @test_throws ArgumentError spliceinto(v, 2:2, falses(4))
        for items in ([2], [-1], [0.5])
            @test_throws InexactError spliceinto(v, 2:3, items)
            @test_throws InexactError @inbounds spliceinto(v, 2:3, items)
        end
        @test_throws MethodError spliceinto(v, 2:3, [:invalid])
        @test v === UVec{UInt8}([1, 0, 1])
    end

end

@testset "Conversion capacity boundaries" failfast = true begin
    for S in (UInt8, UInt16, UInt32, UInt64, UInt128, UInt256, UInt512), D in (UInt8, UInt16, UInt32, UInt64, UInt128, UInt256, UInt512)
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

@testset "Editing boundaries and integer indices" failfast = true begin
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
