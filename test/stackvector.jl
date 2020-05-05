random_stackvector(L::Integer) = StackVector{L}(rand(Bool, L))

@testset "Construction" begin
    @test StackVector() == StackVector{Sys.WORD_SIZE}()
    
    unsafe = StackCollections.unsafe
    @test StackVector{Sys.WORD_SIZE}() == StackVector()
    @test StackVector{Sys.WORD_SIZE}(UInt(11), unsafe) == StackVector(UInt(11), unsafe)
    @test StackVector{Sys.WORD_SIZE}(UInt(0), unsafe) == StackVector(UInt(0), unsafe)
    
    @test_throws TypeError StackVector{Int}()
    @test_throws TypeError StackVector{0x01}()
    
    @test_throws DomainError StackVector{-1}()
    @test_throws DomainError StackVector{99}()
    @test_throws DomainError StackVector{65}()
    
    # Too few
    @test_throws ArgumentError StackVector{2}([true])
    @test_throws ArgumentError StackVector{4}([true, false])
    @test_throws ArgumentError StackVector{9}([true, false, true, true, false])
    
    # Too many
    @test_throws BoundsError StackVector{0}([1])
    @test_throws BoundsError StackVector{4}([true, false, true, false, false])
    @test_throws BoundsError StackVector(rand(Bool, 100))
    
    # Type can't be converted
    @test_throws MethodError StackVector{2}(["y", "n"])
    @test_throws MethodError StackVector{2}([isodd, iseven])
    
    # Value can't be converted
    @test_throws InexactError StackVector{11}(fill(-3, 11))
    @test_throws InexactError StackVector{3}(fill(2, 3))
end

@testset "Basic" begin
    @test eltype(StackVector{5}) == Bool
    for L in [0, 1, 5, 10, 32, 64]
        v = random_stackvector(L)
        @test length(v) == L
    end
end

@testset "Get/setindex" begin
    v = StackVector{6}([0, 1, 1, 1, 0, 0])
    @test_throws BoundsError v[0]
    @test_throws BoundsError v[-4]
    @test_throws BoundsError v[8]
    
    @test v[1] == false
    @test v[3] == true
    
    @test setindex(v, true, 5) == StackVector{6}([0, 1, 1, 1, 1, 0])
    @test setindex(v, false, 2) == StackVector{6}([0, 0, 1, 1, 0, 0])
    @test setindex(v, true, 3) == StackVector{6}([0, 1, 1, 1, 0, 0])
    @test setindex(v, false, 1) == StackVector{6}([0, 1, 1, 1, 0, 0])
    
    for L in [1, 5, 10, 32, 64]
        for i in 1:10
            v = random_stackvector(L)
            v´ = collect(v)
            val = rand(Bool)
            ind = rand(1:L)
            v´[ind] = val
            v = setindex(v, val, ind)
            @test collect(v) == v´    
        end
    end    
end

@testset "Misc" begin
    @test isempty(StackVector{0}())
    @test !isempty(StackVector{9}())
    @test !isempty(random_stackvector(9))
    @test isempty(random_stackvector(0))
    
    @test_throws ArgumentError maximum(random_stackvector(0))
    @test_throws ArgumentError minimum(random_stackvector(0))
    
    @test_throws ArgumentError argmin(random_stackvector(0))
    @test_throws ArgumentError argmax(random_stackvector(0))
    
    for L in [1, 5, 10, 32, 64]
        for i in 1:10
            v = random_stackvector(L)
            v´ = collect(v)
            @test iterate(v)[1] == iterate(v´)[1]
            @test (true in v) == (true in v´)
            @test (false in v) == (false in v´)
            for F in [maximum, minimum, sum, argmin, argmax]
                @test F(v) == F(v´)
            end
            @test [!i for i in v´] == collect(!v)
        end
    end
end

@testset "Predicates" begin
    for (N, F) in enumerate([reverse, x -> circshift(x, 0), x -> circshift(x, -3)])
              #reverse])
              #x -> circshift(x, 0), x -> circshift(x, -3), x -> circshift(x, 500)
              #])
        for L in [1, 5, 10, 32, 64]
            for i in 1:10
                v = random_stackvector(L)
                v´ = collect(v)
                r = F(v)
                r´ = F(v´)
                if r´ === nothing
                    @test r === nothing
                else
                    @test collect(r) == r´
                    if collect(r) != r´
                        println(r)
                        println(r´)
                        println(F, " ", N)
                        println()
                    end
                end
            end
        end
    end
end

#=
x -> findfirst(isodd, x), x -> findfirst(y -> true, x),
x -> findfirst(y -> false, x),
=#
