# the functions the CLI uses to prepare its input; unexported
const RT = RandomizedTukeyHSD

@testset "scores_matrix" begin
    topics = ["t1", "t1", "t2", "t2", "t3", "t3"]
    systems = ["B", "A", "B", "A", "A", "B"]
    scores = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6]

    (matrix, names) = RT.scores_matrix(topics, systems, scores)

    # topics and systems in the order they first appear
    @test names == ["B", "A"]
    @test matrix == [
        0.1 0.2
        0.3 0.4
        0.6 0.5
    ]

    @testset "a pair with no row, and missing, become NaN" begin
        (matrix, names) = RT.scores_matrix(
            ["t1", "t1", "t2"], ["A", "B", "A"], [1.0, missing, 3.0]
        )
        @test names == ["A", "B"]
        @test matrix[1, 1] == 1.0 && matrix[2, 1] == 3.0
        @test isnan(matrix[1, 2]) && isnan(matrix[2, 2])
    end

    @testset "numbers as system names, integer scores" begin
        (matrix, names) = RT.scores_matrix([1, 1, 2, 2], [10, 20, 10, 20],
                                           [1, 2, 3, 4])
        @test names == [10, 20]
        @test matrix == [1.0 2.0; 3.0 4.0]
        @test eltype(matrix) == Float64
    end

    @testset "errors" begin
        @test_throws DimensionMismatch RT.scores_matrix(["t1"], ["A", "B"],
                                                        [1.0, 2.0])
        @test_throws r"topic \"t1\" and system \"A\"" RT.scores_matrix(
            ["t1", "t1"], ["A", "A"], [1.0, 2.0]
        )
    end

    @testset "a matrix built from tidy rows is what the test takes" begin
        (scores, systems) = read_scores(joinpath(DATA, "tiny.csv"))
        r = randomized_tukey_hsd(Xoshiro(1), scores; B=100, systems=systems)
        @test [ x.system1 for x in r ] == ["A", "A", "B"]
    end
end

@testset "incomplete_topics" begin
    scores = [
        1.0 2.0 3.0
        1.0 NaN 3.0
        1.0 2.0 3.0
        NaN NaN 3.0
    ]
    @test RT.incomplete_topics(scores) == [false, true, false, true]
    @test RT.incomplete_topics(scores[[1, 3], :]) == [false, false]

    # dropping them leaves a matrix the test accepts
    kept = scores[.!RT.incomplete_topics(scores), :]
    @test size(kept) == (2, 3)
    @test length(randomized_tukey_hsd(kept; B=10)) == 3
end

@testset "log10_arrangements" begin
    # 3 systems, 4 topics: 6^4 = 1296 arrangements
    @test RT.log10_arrangements(3, 4) ≈ log10(1296)
    @test RT.log10_arrangements(2, 1) ≈ log10(2)
    @test RT.log10_arrangements(1, 5) == 0.0

    # where factorial(nsystems)^ntopics overflowed an Int (10 systems, 50
    # topics) and where factorial(nsystems) itself did (100 systems)
    @test RT.log10_arrangements(10, 50) ≈ 50 * log10(3628800)
    @test isfinite(RT.log10_arrangements(100, 250))
    @test RT.log10_arrangements(100, 250) ≈ 39492.5 atol=0.1
end
