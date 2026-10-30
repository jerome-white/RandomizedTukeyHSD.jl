using Test

@testset "precision targets" begin
    width(target, trials, p) = RandomizedTukeyHSD._width(target, trials, p)

    @testset "StandardError" begin
        @test trials_for(StandardError(0.001)) == 250_000
        @test trials_for(StandardError(0.0005)) == 1_000_000
        @test trials_for(StandardError(0.001); p=0.05) == 47_500

        # rounded up: it meets the target, and one trial fewer than the
        # two before it would not (floating-point error in `se^2` can add
        # one trial to an exact count, as 0.25 / 0.01^2 is not 2500 exactly)
        for se in (0.01, 0.003, 0.0007), p in (0.5, 0.1, 0.05, 0.001)
            n = trials_for(StandardError(se); p=p)
            @test sqrt(p * (1 - p) / n) <= se
            @test sqrt(p * (1 - p) / (n - 2)) > se
        end

        # a target no p-value can miss still takes a trial
        @test trials_for(StandardError(10)) == 1
    end

    @testset "StandardError checks its argument" begin
        @test_throws ArgumentError StandardError(0)
        @test_throws ArgumentError StandardError(-0.1)
        @test_throws ArgumentError StandardError(NaN)
        @test_throws r"se must be positive" StandardError(0)
    end

    @testset "HDIWidth is the least number of trials that meets it" begin
        for w in (0.1, 0.01, 0.002), p in (0.5, 0.05, 0.001)
            target = HDIWidth(w)
            n = trials_for(target; p=p)
            @test width(target, n, p) <= w
            @test n == 1 || width(target, n - 1, p) > w
        end

        target = HDIWidth(0.02; level=0.9, prior=(0.5, 0.5))
        n = trials_for(target; p=0.05)
        @test width(target, n, 0.05) <= 0.02
        @test width(target, n - 1, 0.05) > 0.02
    end

    @testset "HDIWidth is the width hdi reports" begin
        target = HDIWidth(0.01; prior=(2, 3))
        n = trials_for(target; p=0.2)
        (lower, upper) = hdi(MonteCarloPValue(round(Int, 0.2n), n);
                             prior=(2, 3))

        # the count is rounded for hdi, which can move the width a little
        @test upper - lower ≈ 0.01 rtol=0.01
    end

    @testset "HDIWidth agrees with the normal approximation" begin
        # width of a 95% interval is 2 * 1.96 * se when there are many trials
        n = trials_for(HDIWidth(0.002))
        @test n ≈ trials_for(StandardError(0.002 / 3.92)) rtol=0.001

        n = trials_for(HDIWidth(0.002); p=0.05)
        expected = trials_for(StandardError(0.002 / 3.92); p=0.05)
        @test n ≈ expected rtol=0.001
    end

    @testset "a looser target or a p-value away from 0.5 needs less" begin
        @test trials_for(HDIWidth(0.01)) < trials_for(HDIWidth(0.005))
        @test trials_for(HDIWidth(0.01); p=0.05) < trials_for(HDIWidth(0.01))
        @test trials_for(HDIWidth(0.01; level=0.9)) <
            trials_for(HDIWidth(0.01; level=0.99))
        @test trials_for(StandardError(0.01); p=0.05) <
            trials_for(StandardError(0.01))
    end

    @testset "HDIWidth checks its arguments" begin
        @test_throws ArgumentError HDIWidth(0)
        @test_throws ArgumentError HDIWidth(-1)
        @test_throws ArgumentError HDIWidth(0.01; level=0)
        @test_throws ArgumentError HDIWidth(0.01; level=1)
        @test_throws ArgumentError HDIWidth(0.01; prior=(0, 1))
        @test_throws ArgumentError HDIWidth(0.01; prior=(1, 1, 1))
        @test_throws r"prior must be two positive" HDIWidth(0.01; prior=1)
    end

    @testset "p must be strictly between 0 and 1" begin
        for p in (0, 1, -0.1, 1.5, NaN)
            @test_throws ArgumentError trials_for(StandardError(0.01); p=p)
            @test_throws ArgumentError trials_for(HDIWidth(0.01); p=p)
        end
        @test_throws r"p must be strictly" trials_for(StandardError(1); p=1)
    end

    @testset "targets no run could meet are refused" begin
        @test_throws ArgumentError trials_for(StandardError(1e-12))
        @test_throws ArgumentError trials_for(HDIWidth(1e-12))
    end

    @testset "the count feeds FixedTrials" begin
        trials = trials_for(StandardError(0.05))
        @test trials == 100
        @test FixedTrials(trials) isa FixedTrials
    end

    @testset "a new kind of target needs one method" begin
        struct Fixed500 end
        RandomizedTukeyHSD.trials_for(::Fixed500, p) = 500

        @test trials_for(Fixed500()) == 500
        @test_throws ArgumentError trials_for(Fixed500(); p=2)
    end
end
