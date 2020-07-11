@testset "Construction" begin
    @test OneHotVector(10, 1) == OneHotVector(10, 1)
    @test_throws ArgumentError OneHotVector(1, 10)
    @test_throws ArgumentError OneHotVector(0, 1)
    
    arr = zeros(Bool, 4)
    @test_throws ArgumentError OneHotVector(arr)
    arr[2] = true
    @test OneHotVector(arr) == OneHotVector(4, 2)
    arr[4] = true
    @test_throws ArgumentError OneHotVector(arr)
end

@testset "Basics" begin
    @test eltype(OneHotVector) == Bool
    @test length(OneHotVector(1, 1)) == 1
    @test length(OneHotVector(23241, 9)) == 23241
end

@testset "Getindex" begin
    v = OneHotVector(11, 3)
    @test_throws BoundsError v[0]
    @test_throws BoundsError v[-5]
    @test_throws BoundsError v[15]
    
    @test !(v[11])
    @test v[3]
    
    @test first(OneHotVector(1, 1))
end

@testset "Misc" begin
    for len in [1, 2, 4, 9, 11, 22, 115, 500]
        for i in 1:5
            v = OneHotVector(len, rand(1:len))
            v´ = collect(v)
            
            for F in [argmax, argmin, sum, count, allunique,
                      x -> findfirst(isodd, x), x -> findfirst(isequal(4), x)]
                @test F(v) == F(v´)
            end
            
            for F in [reverse, x -> circshift(x, 1), x -> circshift(x, -5),
                      x -> circshift(x, 500), x -> filter(iseven, x),
                      x -> filter(y -> true, x), x -> filter(isequal(3), x)]
                @test collect(F(v)) == F(v´)
            end
        end
    end
end
