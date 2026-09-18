@testset "Editing and conversion across backing widths" begin
    for U in (UInt8, UInt16, UInt32, UInt64, UInt128)
        @testset "$U" begin
            T = UVec{U}
            cap = capacity(T)
            for len in 0:cap
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
                    for i in 1:(len + 1), b in (false, true)
                        if len < cap
                            @test insert(v, i, b) === T(insert!(copy(data), i, b))
                        else
                            @test_throws ArgumentError insert(v, i, b)
                        end
                    end
                    for i in 1:len
                        @test deleteat(v, i) === T(deleteat!(copy(data), i))
                        for j in i:len
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

@testset "Editing boundaries and integer indices" begin
    v = UVec{UInt8}([1, 0, 1])
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
    @test_throws BoundsError deleteat(v, 4)
    @test_throws BoundsError insert(v, 0, 2)
    @test_throws InexactError insert(v, 2, 2)
    @test_throws InexactError pushfirst(v, false, 2)
    @test_throws ArgumentError pushfirst(v, false, true, false)
    @test (@inbounds deleteat(v, 2)) === UVec{UInt8}([1, 1])
    @test (@inbounds deleteat(v, 1:3)) === UVec{UInt8}()
    @test (@inbounds insert(v, 2, false)) === UVec{UInt8}([1, 0, 0, 1])
    @test (@inbounds pushfirst(v, false, true)) === UVec{UInt8}([0, 1, 1, 0, 1])
    @test (@inbounds UVec{UInt16}(v)) === UVec{UInt16}([1, 0, 1])
    @test_throws InexactError @inbounds insert(v, 2, 2)
end
