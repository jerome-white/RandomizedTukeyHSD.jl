using Random

# A generator that returns the numbers it was given, in order, so that a test
# can choose what the shuffle draws.
mutable struct Scripted <: AbstractRNG
    numbers::Vector{UInt64}
    drawn::Int
end

Scripted(numbers) = Scripted(numbers, 0)

function Random.rand(rng::Scripted, ::Random.SamplerType{UInt64})
    rng.drawn += 1
    return rng.numbers[rng.drawn]
end

# The package's own shuffle (issue #96): every arrangement of a block must
# be equally likely, or the p-values are biased.
@testset "shuffle" begin
    shuffle! = RandomizedTukeyHSD._shuffle!

    @testset "the result is an arrangement of the input" begin
        rng = Xoshiro(1)
        for n in (0, 1, 2, 3, 10, 1000)
            values = rand(Xoshiro(n), n)
            before = copy(values)

            @test shuffle!(rng, values) === values
            @test sort(values) == sort(before)
        end
    end

    @testset "nothing is drawn for fewer than two values" begin
        rng = Xoshiro(1)
        shuffle!(rng, Float64[])
        shuffle!(rng, [1.0])
        @test rng == Xoshiro(1)
    end

    @testset "a function of the stream" begin
        a = shuffle!(Xoshiro(5), collect(1:50))
        b = shuffle!(Xoshiro(5), collect(1:50))
        c = shuffle!(Xoshiro(6), collect(1:50))

        @test a == b
        @test a != c
        @test a != 1:50
    end

    @testset "a column of a matrix, as a trial shuffles it" begin
        data = collect(reshape(1.0:12.0, 3, 4))
        before = copy(data)
        rng = Xoshiro(2)
        moved = false
        for _ in 1:20
            shuffle!(rng, view(data, :, 2))
            moved |= data[:, 2] != before[:, 2]
        end

        @test moved
        @test sort(data[:, 2]) == before[:, 2]
        @test data[:, [1, 3, 4]] == before[:, [1, 3, 4]]
    end

    @testset "every arrangement of four values is equally likely" begin
        n = 240_000
        counts = Dict{Vector{Int}, Int}()
        rng = Xoshiro(3)
        items = Vector{Int}(undef, 4)
        for _ in 1:n
            items .= 1:4
            shuffle!(rng, items)
            counts[copy(items)] = get(counts, items, 0) + 1
        end

        # 24 arrangements, each a binomial count with probability 1/24
        @test length(counts) == 24
        limit = 5 * sqrt(n * (1 / 24) * (23 / 24))
        @test all(abs.(values(counts) .- n / 24) .< limit)
    end

    @testset "every value is equally likely at every position" begin
        n = 70_000
        len = 7
        counts = zeros(Int, len, len)
        rng = Xoshiro(4)
        items = Vector{Int}(undef, len)
        for _ in 1:n
            items .= 1:len
            shuffle!(rng, items)
            for (position, value) in enumerate(items)
                counts[position, value] += 1
            end
        end

        limit = 5 * sqrt(n * (1 / len) * (1 - 1 / len))
        @test all(abs.(counts .- n / len) .< limit)
    end

    @testset "the draw for each position" begin
        # The position swapped with the last of three is the high half of
        # the number drawn times 3: the thirds of the 64-bit numbers map to
        # the first, second and third position. Then one more number is
        # drawn for the last of two, and its halves map to the two.
        third = div(typemax(UInt64), 3)
        half = div(typemax(UInt64), 2)

        @test shuffle!(Scripted([1, 1]), [1, 2, 3]) == [2, 3, 1]
        @test shuffle!(Scripted([third + 2, 1]), [1, 2, 3]) == [3, 1, 2]
        @test shuffle!(Scripted([2 * third + 3, 1]), [1, 2, 3]) == [2, 1, 3]
        @test shuffle!(Scripted([1, half + 1]), [1, 2, 3]) == [3, 2, 1]
    end

    @testset "a number that would bias the draw is drawn again" begin
        # 2^64 is 1 more than a multiple of 3, so one of the 2^64 numbers
        # has to be turned away for the three positions to be equally
        # likely: it is 0. With 0 first, the shuffle is the one of the
        # numbers that follow, and three numbers are drawn, not two.
        numbers = UInt64[0x9e3779b97f4a7c15, 0x3c6ef372fe94f82a]
        expected = shuffle!(Scripted(numbers), [1, 2, 3])

        rng = Scripted(vcat(UInt64(0), numbers))
        @test shuffle!(rng, [1, 2, 3]) == expected
        @test rng.drawn == 3

        # for two positions no number is turned away, 0 included
        rng = Scripted(UInt64[0])
        @test shuffle!(rng, [1, 2]) == [2, 1]
        @test rng.drawn == 1
    end
end
