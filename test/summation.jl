using Random

# The means that decide whether a trial reaches the observed difference are
# added in a fixed order, so the result does not depend on how Julia was
# started (issue #74). `Base.mean` and `sum` with `dims` may add in another
# order with and without `--check-bounds=yes`; a unit test cannot start Julia
# differently, so these tests pin the properties the fixed order gives.
@testset "treatment means add in a fixed order" begin
    rng = Xoshiro(74)

    @testset "$nblocks blocks, $ntreatments treatments" for
            (nblocks, ntreatments) in ((3, 3), (4, 5), (11, 4), (50, 6))
        responses = rand(rng, nblocks, ntreatments)
        means = zeros(ntreatments)

        # bit for bit the test's own left-to-right sum, whether the data
        # arrive as a matrix or as a lazy transpose of the responses
        RandomizedTukeyHSD._row_means!(means, transpose(responses))
        @test means == column_means(responses)

        RandomizedTukeyHSD._row_means!(means, collect(transpose(responses)))
        @test means == column_means(responses)
    end

    # Relabeling the treatments the same way in every block only reorders the
    # treatment means, so the range of a trial that does it equals the largest
    # observed difference exactly, not just to rounding. This is what makes
    # such a trial count, in every mode.
    @testset "a relabeling has exactly the observed range" begin
        responses = rand(rng, 5, 4)
        data = collect(transpose(responses))
        means = RandomizedTukeyHSD._row_means!(zeros(4), data)
        observed = maximum(means) - minimum(means)

        for relabeling in permutations_of(4)
            relabeled = RandomizedTukeyHSD._row_means!(
                zeros(4), data[relabeling, :]
            )
            @test maximum(relabeled) - minimum(relabeled) == observed
        end
    end
end
