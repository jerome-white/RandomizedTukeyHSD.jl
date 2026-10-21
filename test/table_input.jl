using DataFrames

# the tables hold the same scores as SCORES (4 topics × 3 systems) so every
# form can be compared with the matrix method for the same generator state
const TOPICS = [ "t$i" for i in 1:4 ]

wide_columns() = (topic=TOPICS,
                  A=SCORES[:, 1], B=SCORES[:, 2], C=SCORES[:, 3])

function tidy_columns_of(; shuffled=false)
    rows = [ (TOPICS[i], NAMES[j], SCORES[i, j]) for i in 1:4, j in 1:3 ]
    rows = vec(permutedims(rows))
    shuffled && (rows = rows[randperm(MersenneTwister(1), length(rows))])

    return (dataset=[ r[1] for r in rows ],
            model=[ r[2] for r in rows ],
            accuracy=[ r[3] for r in rows ])
end

@testset "tables" begin
    expected = randomized_tukey_hsd(Xoshiro(1), SCORES; trials=500,
                                    systems=NAMES)

    @testset "wide" begin
        wide = (A=SCORES[:, 1], B=SCORES[:, 2], C=SCORES[:, 3])
        @test randomized_tukey_hsd(Xoshiro(1), wide; trials=500) == expected

        # names come with the data, as strings
        r = randomized_tukey_hsd(Xoshiro(1), wide; trials=500)
        @test [ (x.system1, x.system2) for x in r ] ==
            [("A", "B"), ("A", "C"), ("B", "C")]

        # an id column is left out with block, as a Symbol or a String
        withid = wide_columns()
        @test randomized_tukey_hsd(Xoshiro(1), withid; trials=500,
                                   block=:topic) == expected
        @test randomized_tukey_hsd(Xoshiro(1), withid; trials=500,
                                   block="topic") == expected
    end

    @testset "tidy" begin
        tidy = tidy_columns_of()
        @test randomized_tukey_hsd(Xoshiro(1), tidy; trials=500,
                                   block=:dataset, treatment=:model,
                                   value=:accuracy) == expected

        # rows in any order give the same pairs and differences (up to the
        # last bit: the topics are summed in another order). The p-values
        # are not compared: another order of appearance puts the treatments
        # in other columns, so the same generator state shuffles differently.
        shuffled = tidy_columns_of(shuffled=true)
        r = randomized_tukey_hsd(Xoshiro(1), shuffled; trials=500,
                                 block="dataset", treatment="model",
                                 value="accuracy")
        key(x) = Set([x.system1, x.system2])
        got = Dict(key(x) => abs(x.difference) for x in r)
        want = Dict(key(x) => abs(x.difference) for x in expected)
        @test keys(got) == keys(want)
        @test all(got[k] ≈ want[k] for k in keys(want))
    end

    @testset "other kinds of table" begin
        wide = (A=SCORES[:, 1], B=SCORES[:, 2], C=SCORES[:, 3])

        # a vector of named tuples (rows)
        rows = [ (A=wide.A[i], B=wide.B[i], C=wide.C[i]) for i in 1:4 ]
        @test randomized_tukey_hsd(Xoshiro(1), rows; trials=500) == expected

        # a DataFrame, wide and tidy
        @test randomized_tukey_hsd(Xoshiro(1), DataFrame(wide);
                                   trials=500) == expected
        @test randomized_tukey_hsd(Xoshiro(1), DataFrame(tidy_columns_of());
                                   trials=500, block=:dataset,
                                   treatment=:model,
                                   value=:accuracy) == expected
    end

    @testset "default generator" begin
        wide = (A=SCORES[:, 1], B=SCORES[:, 2], C=SCORES[:, 3])
        Random.seed!(2)
        first = randomized_tukey_hsd(wide; trials=500)
        Random.seed!(2)
        @test randomized_tukey_hsd(wide; trials=500) == first
    end

    @testset "missing and absent scores are NaN, then rejected" begin
        gap = (A=[0.1, 0.2, 0.3], B=[0.4, missing, 0.6])
        @test_throws r"1 NaN" randomized_tukey_hsd(gap; trials=10)

        tidy = (b=["t1", "t1", "t2"], t=["A", "B", "A"], v=[1.0, 2.0, 3.0])
        @test_throws r"1 NaN" randomized_tukey_hsd(tidy; trials=10,
                                                   block=:b, treatment=:t,
                                                   value=:v)
    end

    @testset "matrices keep taking the matrix method" begin
        @test randomized_tukey_hsd(Xoshiro(1), SCORES; trials=500,
                                   systems=NAMES) == expected

        # not real: would read as a table with columns Column1, ...
        gappy = Union{Missing,Float64}[0.1 0.4; 0.2 missing]
        @test_throws r"matrix must have real elements" randomized_tukey_hsd(
            gappy; trials=10
        )
    end

    @testset "errors" begin
        wide = (A=SCORES[:, 1], B=SCORES[:, 2])
        tidy = tidy_columns_of()
        all3 = (block=:dataset, treatment=:model, value=:accuracy)

        @test_throws r"expected a matrix or a Tables.jl table" (
            randomized_tukey_hsd(5; trials=10)
        )
        @test_throws r"no column :nope for the block" randomized_tukey_hsd(
            wide; trials=10, block=:nope
        )
        @test_throws r"give block, treatment and value" randomized_tukey_hsd(
            tidy; trials=10, block=:dataset, treatment=:model
        )
        @test_throws r"give block, treatment and value" randomized_tukey_hsd(
            tidy; trials=10, value=:accuracy
        )
        @test_throws r"different columns" randomized_tukey_hsd(
            tidy; trials=10, block=:dataset, treatment=:dataset,
            value=:accuracy
        )
        @test_throws ArgumentError randomized_tukey_hsd(
            tidy; trials=0, all3...
        )
        # names come from the table, so there is no systems argument
        @test_throws MethodError randomized_tukey_hsd(
            wide; trials=10, systems=["A", "B"]
        )
    end
end
