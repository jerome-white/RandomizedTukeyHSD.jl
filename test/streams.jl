using Random
using Statistics

# The random stream of every trial depends on the base seed and the number of
# the trial alone (issue #34).
@testset "trial streams" begin
    stream = RandomizedTukeyHSD._stream
    base = rand(Xoshiro(1), UInt64)

    @testset "a stream is a function of the base and the trial" begin
        draw(base, i) = rand(stream(base, i), UInt64, 4)

        @test draw(base, 5) == draw(base, 5)
        @test draw(base, 5) != draw(base, 6)
        @test draw(base, 5) != draw(base + 1, 5)
        @test draw(base, 6) != draw(base + 1, 5)
    end

    # The state of a stream is made with SplitMix64 (issue #109). Its first
    # outputs for the seed 1234567 are published with the algorithm.
    @testset "SplitMix64 gives its published values" begin
        splitmix64 = RandomizedTukeyHSD._splitmix64
        published = [
            6457827717110365317,
            3203168211198807973,
            9817491932198370423,
            4593380528125082431,
            16408922859458223821,
        ]

        for (n, value) in enumerate(published)
            @test splitmix64(UInt64(1234567), UInt64(n)) == value
        end
    end

    # A stream is xoshiro256++ started from four outputs of SplitMix64: the
    # numbers it gives are compared with the algorithm written out here
    # (Blackman and Vigna, `xoshiro256plusplus.c`), so they do not depend on
    # the version of Julia.
    @testset "a stream is xoshiro256++ from SplitMix64" begin
        splitmix64 = RandomizedTukeyHSD._splitmix64
        rotl(x, k) = (x << k) | (x >> (64 - k))

        for i in (1, 2, 1000)
            n = 4 * (UInt64(i) - 1)
            state = [ splitmix64(base, n + k) for k in 1:4 ]

            expected = UInt64[]
            for _ in 1:5
                push!(expected, rotl(state[1] + state[4], 23) + state[1])
                t = state[2] << 17
                state[3] = xor(state[3], state[1])
                state[4] = xor(state[4], state[2])
                state[2] = xor(state[2], state[3])
                state[1] = xor(state[1], state[4])
                state[3] = xor(state[3], t)
                state[4] = rotl(state[4], 45)
            end

            g = stream(base, i)
            @test [ rand(g, UInt64) for _ in 1:5 ] == expected
        end
    end

    @testset "neighbouring trials are not correlated" begin
        n = 100_000
        draws = Matrix{Float64}(undef, n, 3)
        for i in 1:n
            g = stream(base, i)
            draws[i, :] = rand(g, 3)
        end

        # uniform on [0, 1): mean 1/2, variance 1/12
        @test all(abs.(mean(draws; dims=1) .- 0.5) .< 5 * sqrt(1 / 12 / n))

        # correlation of trial i with trial i + 1, for each draw, and of
        # the draws of one trial with each other
        limit = 5 / sqrt(n)
        for j in 1:3
            @test abs(cor(draws[1:end-1, j], draws[2:end, j])) < limit
        end
        @test abs(cor(draws[:, 1], draws[:, 2])) < limit
        @test abs(cor(draws[:, 2], draws[:, 3])) < limit

        # indices that differ by a power of two, where bad mixing shows
        for lag in (2, 4, 64, 1024)
            @test abs(cor(draws[1:end-lag, 1], draws[1+lag:end, 1])) < limit
        end
    end
end
