random_stackvector(L) =  StackVector(rand(UInt) & (1 << (L&63) - 1), L)

@testset "Construction" begin
    @test_throws DomainError StackVector(zero(UInt), 65)

    @test StackVector([1, 0, 1, 1, 0, 1]) !== false

    @test StackVector([0, 1, 1, 0]) isa StackVector
    @test StackVector() === StackVector()
    toolong = rand(Bool, 65)
    @test_throws DomainError StackVector(toolong)
end

@testset "Basic" begin
    v_ = [0, 1, 1, 0, 1, 1, 1, 0, 0, 1]
    v = StackVector(v_)
    @test length(v) == 10
    @test size(v) == (10,)

    @test !isempty(v_)
    @test isempty(StackVector())
end

@testset "Get/set index" begin
    # Get index
    v_ = [0, 1, 1, 0, 1, 1, 1, 0, 0, 1]
    v = StackVector(v_)
    @test !v[1]
    @test v[2]
    @test !v[4]
    @test collect(v) == v_

    # Set index
    v2 = setindex(v, true, 4)
    @test v2[4]
    @test length(v) == length(v2)
end

@testset "Push/pop" begin
    v = StackVector()
    @test_throws ArgumentError pop(v)
    v = StackVector(fill(true, 64))
    @test_throws DomainError push(v, true)

    for L in [1, 3, 50, 63]
        for i in 1:3
            v = random_stackvector(L)
            v´ = collect(v)
            @test collect(pop(v)) == (v´´ = copy(v); pop!(v´´); v´´)
            @test collect(push(v, true)) == push!(copy(v´), true)
            @test collect(push(v, 0)) == push!(copy(v´), 0)
        end
    end
end

@testset "Iteration" begin
    for L in [0, 1, 3, 50]
        for i in 1:3
            v = random_stackvector(L)
            @test Bool[v[j] for j in 1:L] == Bool[j for j in v]
        end
    end
end

@testset "Misc" begin
    # In
    v = StackVector([true, 1, 0x01, 0x0000])
    @test (true in v)
    @test (false in v)

    v = StackVector([true, true, true, true])
    @test (true in v)
    @test !(false in v)

    # Inversion
    @test ~StackVector([0, 1, 1, 0]) == StackVector([1, 0, 0, 1])
    @test ~StackVector([0, 1, 0]) == StackVector([1, 0, 1])
end

@testset "Sum" begin
    for L in [0, 1, 3, 9, 64]
        for i in 1:3
            v = random_stackvector(L)
            @test sum(v) == sum(collect(v))
        end
    end
end

@testset "Min/max" begin
    for F in [argmin, argmax, minimum, maximum, findfirst,
             x -> findfirst(~, x), x -> findfirst(y -> true, x)]
        if F in [argmin, argmax, minimum, maximum]
            @test_throws ArgumentError F(StackVector())
        end
        for L in [1, 2, 3, 11, 64]
            for i in 1:10
                v = random_stackvector(L)
                @test F(v) == F(collect(v))
            end
        end
    end
end

@testset "Empty transformations" begin
    for f in [reverse, (x -> circshift(x, 3)), (x -> circshift(x, -301)), ~]
        @test f(StackVector()) === StackVector()
    end
end

@testset "Transformations" begin
    for F in [reverse, x -> circshift(x, 0), x -> circshift(x, -3),
             x -> circshift(x, -102), x -> circshift(x, 69), x -> circshift(x, 4)]
        for L in [1, 3, 10]
            for i in 1:3
                v = random_stackvector(L)
                @test collect(F(v)) == F(collect(v))
            end
        end
    end
end

@testset "Convert to bitvector" begin
    for L in [1, 2, 3, 11, 64]
        for i in 1:10
            v = random_stackvector(L)
            @test convert(BitVector, v) == BitVector(collect(v))
        end
    end
end
