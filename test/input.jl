# the functions that arrange tidy and wide data into a matrix; unexported
const RT = RandomizedTukeyHSD

@testset "tidy_matrix" begin
    blocks = ["b1", "b1", "b2", "b2", "b3", "b3"]
    treatments = ["B", "A", "B", "A", "A", "B"]
    responses = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6]

    (matrix, names) = RT.tidy_matrix(blocks, treatments, responses)

    # blocks and treatments in the order they first appear
    @test names == ["B", "A"]
    @test matrix == [
        0.1 0.2
        0.3 0.4
        0.6 0.5
    ]

    @testset "a pair with no row, and missing, become NaN" begin
        (matrix, names) = RT.tidy_matrix(
            ["b1", "b1", "b2"], ["A", "B", "A"], [1.0, missing, 3.0]
        )
        @test names == ["A", "B"]
        @test matrix[1, 1] == 1.0 && matrix[2, 1] == 3.0
        @test isnan(matrix[1, 2]) && isnan(matrix[2, 2])
    end

    @testset "numbers as treatment names, integer responses" begin
        (matrix, names) = RT.tidy_matrix([1, 1, 2, 2], [10, 20, 10, 20],
                                           [1, 2, 3, 4])
        @test names == [10, 20]
        @test matrix == [1.0 2.0; 3.0 4.0]
        @test eltype(matrix) == Float64
    end

    @testset "errors" begin
        @test_throws DimensionMismatch RT.tidy_matrix(["b1"], ["A", "B"],
                                                        [1.0, 2.0])
        @test_throws r"block \"b1\" and treatment \"A\"" RT.tidy_matrix(
            ["b1", "b1"], ["A", "A"], [1.0, 2.0]
        )
    end

    @testset "a matrix built from tidy rows is what the test takes" begin
        (responses, treatments) = read_responses(joinpath(DATA, "tiny.csv"))
        r = randomized_tukey_hsd(Xoshiro(1), responses; trials=100,
                                 treatments=treatments)
        @test [ x.treatment1 for x in r ] == ["A", "A", "B"]
    end
end

@testset "wide_matrix" begin
    (matrix, names) = RT.wide_matrix(
        ["A", "B"], [[0.1, 0.2, 0.3], [1, missing, 3]]
    )
    @test names == ["A", "B"]
    @test matrix[:, 1] == [0.1, 0.2, 0.3]
    @test matrix[1, 2] == 1.0 && matrix[3, 2] == 3.0
    @test isnan(matrix[2, 2])

    @test_throws DimensionMismatch RT.wide_matrix(["A"], [[1.0], [2.0]])
    @test_throws DimensionMismatch RT.wide_matrix(
        ["A", "B"], [[1.0, 2.0], [1.0]]
    )
    @test_throws r"column \"B\" is not numeric" RT.wide_matrix(
        ["A", "B"], [[1.0, 2.0], ["x", "y"]]
    )
end
