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
        r = randomized_tukey_hsd(Xoshiro(1), scores; trials=100,
                                 systems=systems)
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
    @test length(randomized_tukey_hsd(kept; trials=10)) == 3
end

@testset "tidy_columns" begin
    pick(names; block=nothing, treatment=nothing, value=nothing) =
        RT.tidy_columns(names, block, treatment, value)

    # the IR names, in any order, and extra columns
    @test pick(["topic", "system", "score"]) == ("topic", "system", "score")
    @test pick(["score", "system", "topic", "run"]) ==
        ("topic", "system", "score")

    # asked for explicitly
    @test pick(["a", "b", "c"]; block="c", treatment="a", value="b") ==
        ("c", "a", "b")
    @test pick(["dataset", "model", "accuracy", "note"]; block="dataset",
               treatment="model", value="accuracy") ==
        ("dataset", "model", "accuracy")

    # three columns with other names: in the order block, treatment, value
    @test pick(["dataset", "model", "accuracy"]) ==
        ("dataset", "model", "accuracy")

    # a role given, the rest decided from what is left
    @test pick(["dataset", "model", "accuracy"]; value="dataset") ==
        ("model", "accuracy", "dataset")
    @test pick(["topic", "model", "accuracy"]) ==
        ("topic", "model", "accuracy")

    @testset "errors" begin
        @test_throws r"cannot tell which columns" pick(["a", "b", "c", "d"])
        @test_throws r"no column \"x\" for the treatment" pick(
            ["a", "b", "c"]; treatment="x"
        )
        @test_throws r"different columns" pick(
            ["a", "b", "c"]; block="a", treatment="a", value="b"
        )
    end
end

@testset "wide_scores" begin
    (matrix, names) = RT.wide_scores(
        ["A", "B"], [[0.1, 0.2, 0.3], [1, missing, 3]]
    )
    @test names == ["A", "B"]
    @test matrix[:, 1] == [0.1, 0.2, 0.3]
    @test matrix[1, 2] == 1.0 && matrix[3, 2] == 3.0
    @test isnan(matrix[2, 2])
    @test RT.incomplete_topics(matrix) == [false, true, false]

    @test_throws DimensionMismatch RT.wide_scores(["A"], [[1.0], [2.0]])
    @test_throws DimensionMismatch RT.wide_scores(
        ["A", "B"], [[1.0, 2.0], [1.0]]
    )
    @test_throws r"column \"B\" is not numeric" RT.wide_scores(
        ["A", "B"], [[1.0, 2.0], ["x", "y"]]
    )
end
