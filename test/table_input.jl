using DataFrames

# the tables hold the same responses as RESPONSES (4 blocks × 3 treatments)
# so every form can be compared with the matrix method for the same
# generator state
const BLOCKS = [ "b$i" for i in 1:4 ]

wide_table_of() = (block=BLOCKS,
                  A=RESPONSES[:, 1], B=RESPONSES[:, 2], C=RESPONSES[:, 3])

function tidy_table_of(; shuffled=false)
    rows = [ (BLOCKS[i], TREATMENTS[j], RESPONSES[i, j])
             for i in 1:4, j in 1:3 ]
    rows = vec(permutedims(rows))
    shuffled && (rows = rows[randperm(MersenneTwister(1), length(rows))])

    return (dataset=[ r[1] for r in rows ],
            model=[ r[2] for r in rows ],
            accuracy=[ r[3] for r in rows ])
end

@testset "tables" begin
    expected = tukey(Xoshiro(1), RESPONSES; trials=500,
                     treatments=TREATMENTS)
    expected_symbols = tukey(Xoshiro(1), RESPONSES; trials=500,
                             treatments=Symbol.(TREATMENTS))

    @testset "wide" begin
        wide = (A=RESPONSES[:, 1], B=RESPONSES[:, 2], C=RESPONSES[:, 3])
        @test tukey(Xoshiro(1), wide; trials=500) ==
            expected_symbols

        # names come with the data, as the Symbols the table gives
        r = tukey(Xoshiro(1), wide; trials=500)
        @test [ (x.treatment1, x.treatment2) for x in r ] ==
            [(:A, :B), (:A, :C), (:B, :C)]

        # an id column is left out with block, as a Symbol or a String
        withid = wide_table_of()
        @test tukey(Xoshiro(1), withid; trials=500,
                    block=:block) == expected_symbols
        @test tukey(Xoshiro(1), withid; trials=500,
                    block="block") == expected_symbols
    end

    @testset "tidy" begin
        tidy = tidy_table_of()
        @test tukey(Xoshiro(1), tidy; trials=500,
                    block=:dataset, treatment=:model,
                    response=:accuracy) == expected

        # rows in any order give the same pairs and differences (up to the
        # last bit: the blocks are summed in another order). The p-values
        # are not compared: another order of appearance puts the treatments
        # in other columns, so the same generator state shuffles differently.
        shuffled = tidy_table_of(shuffled=true)
        r = tukey(Xoshiro(1), shuffled; trials=500,
                  block="dataset", treatment="model",
                  response="accuracy")
        key(x) = Set([x.treatment1, x.treatment2])
        got = Dict(key(x) => abs(x.difference) for x in r)
        want = Dict(key(x) => abs(x.difference) for x in expected)
        @test keys(got) == keys(want)
        @test all(got[k] ≈ want[k] for k in keys(want))
    end

    @testset "other kinds of table" begin
        wide = (A=RESPONSES[:, 1], B=RESPONSES[:, 2], C=RESPONSES[:, 3])

        # a vector of named tuples (rows)
        rows = [ (A=wide.A[i], B=wide.B[i], C=wide.C[i]) for i in 1:4 ]
        @test tukey(Xoshiro(1), rows; trials=500) ==
            expected_symbols

        # a DataFrame, wide and tidy
        @test tukey(Xoshiro(1), DataFrame(wide);
                    trials=500) == expected_symbols
        @test tukey(Xoshiro(1), DataFrame(tidy_table_of());
                    trials=500, block=:dataset,
                    treatment=:model,
                    response=:accuracy) == expected
    end

    @testset "default generator" begin
        wide = (A=RESPONSES[:, 1], B=RESPONSES[:, 2], C=RESPONSES[:, 3])
        Random.seed!(2)
        first = tukey(wide; trials=500)
        Random.seed!(2)
        @test tukey(wide; trials=500) == first
    end

    @testset "missing and absent responses are NaN, then rejected" begin
        gap = (A=[0.1, 0.2, 0.3], B=[0.4, missing, 0.6])
        @test_throws r"1 NaN" tukey(gap; trials=10)

        tidy = (b=["b1", "b1", "b2"], t=["A", "B", "A"], v=[1.0, 2.0, 3.0])
        @test_throws r"1 NaN" tukey(tidy; trials=10,
                                    block=:b, treatment=:t,
                                    response=:v)
    end

    @testset "matrices keep taking the matrix method" begin
        @test tukey(Xoshiro(1), RESPONSES; trials=500,
                    treatments=TREATMENTS) == expected

        # not real: would read as a table with columns Column1, ...
        gappy = Union{Missing,Float64}[0.1 0.4; 0.2 missing]
        @test_throws r"matrix must have real elements" tukey(
            gappy; trials=10
        )
    end

    @testset "errors" begin
        wide = (A=RESPONSES[:, 1], B=RESPONSES[:, 2])
        tidy = tidy_table_of()
        all3 = (block=:dataset, treatment=:model, response=:accuracy)

        @test_throws r"expected a matrix or a Tables.jl table" (
            tukey(5; trials=10)
        )
        @test_throws r"no column :nope for the block" tukey(
            wide; trials=10, block=:nope
        )
        @test_throws r"give block, treatment and response" tukey(
            tidy; trials=10, block=:dataset, treatment=:model
        )
        @test_throws r"give block, treatment and response" tukey(
            tidy; trials=10, response=:accuracy
        )
        @test_throws r"different columns" tukey(
            tidy; trials=10, block=:dataset, treatment=:dataset,
            response=:accuracy
        )
        @test_throws ArgumentError tukey(
            tidy; trials=0, all3...
        )
        # names come from the table, so there is no treatments argument
        @test_throws MethodError tukey(
            wide; trials=10, treatments=["A", "B"]
        )
    end
end
