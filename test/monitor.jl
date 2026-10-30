using Logging
using Random
using Test

# Keeps every checkpoint it is shown.
struct Collect
    seen::Vector{Checkpoint}
end

Collect() = Collect(Checkpoint[])

RandomizedTukeyHSD.emit(monitor::Collect, checkpoint::Checkpoint) =
    push!(monitor.seen, checkpoint)

@testset "monitors" begin
    responses = [0.10 0.40 0.70; 0.20 0.50 0.60; 0.15 0.45 0.80;
                 0.25 0.35 0.65]
    problem = RandomizedTukeyProblem(responses; treatments=["A", "B", "C"])
    rule = FixedTrials(300)    # 4 full chunks of 64 and one of 44

    plain = solve(problem, rule; rng=Xoshiro(1))

    @testset "NoMonitor is the default and does nothing" begin
        @test solve(problem, rule; rng=Xoshiro(1), monitor=NoMonitor()) ==
            plain
        @test init(problem, rule; rng=Xoshiro(1)).monitor isa NoMonitor
        @test RandomizedTukeyHSD.emit(
            NoMonitor(), Checkpoint(1, 2, MonteCarloPValue[], false)
        ) === nothing
    end

    @testset "checkpoints every `every` trials, rounded up to chunks" begin
        monitor = Collect()
        solve(problem, rule; rng=Xoshiro(1), monitor=monitor, every=100)

        # 100 trials is two chunks: 128 and 256 trials, then the last
        @test [ c.trials for c in monitor.seen ] == [128, 256, 300]
        @test [ c.done for c in monitor.seen ] == [false, false, true]
        @test all(c -> c.planned == 300, monitor.seen)
    end

    @testset "by default about 1% of the trials apart" begin
        monitor = Collect()
        solve(problem, rule; rng=Xoshiro(1), monitor=monitor)

        # 1% of 300 is 3 trials, so one chunk at a time
        @test [ c.trials for c in monitor.seen ] == [64, 128, 192, 256, 300]
    end

    @testset "a checkpoint has the p-values so far" begin
        monitor = Collect()
        results = solve(problem, rule; rng=Xoshiro(1), monitor=monitor,
                        every=64)
        last = monitor.seen[end]

        @test last.pvalues isa Vector{MonteCarloPValue}
        @test all(p -> p.trials == 300, last.pvalues)
        @test [ pvalue(p) for p in last.pvalues ] ==
            [ r.pvalue for r in results ]
        @test [ p.trials for p in monitor.seen[2].pvalues ] == [128, 128, 128]
    end

    @testset "the results do not depend on the monitor or its spacing" begin
        for every in (1, 64, 65, 100, 300, 1000)
            monitor = Collect()
            results = solve(problem, rule; rng=Xoshiro(1),
                            monitor=monitor, every=every)
            @test results == plain
            @test monitor.seen[end].done
        end
    end

    @testset "a monitor is shown a copy and cannot change the run" begin
        struct Vandal end
        function RandomizedTukeyHSD.emit(::Vandal, checkpoint)
            empty!(checkpoint.pvalues)
        end

        run = init(problem, rule; rng=Xoshiro(1), monitor=Vandal(), every=64)
        @test solve!(run) == plain
        @test length(pvalues(run)) == 3

        @test fieldnames(Checkpoint) == (:trials, :planned, :pvalues, :done)
    end

    @testset "a monitor that throws stops the run" begin
        struct Stop end
        RandomizedTukeyHSD.emit(::Stop, checkpoint) = error("stop")

        run = init(problem, rule; rng=Xoshiro(1), monitor=Stop(), every=64)
        @test_throws ErrorException solve!(run)
        @test trials(run) == 64
    end

    @testset "a finished run emits nothing more" begin
        monitor = Collect()
        run = init(problem, rule; rng=Xoshiro(1), monitor=monitor)
        solve!(run)
        count = length(monitor.seen)
        solve!(run)
        @test length(monitor.seen) == count
    end

    @testset "every must be positive" begin
        @test_throws ArgumentError init(problem, rule; every=0)
        @test_throws r"every must be positive, got -5" init(
            problem, rule; every=-5
        )
    end

    @testset "LogMonitor" begin
        @testset "emits nothing at the default level" begin
            @test_logs solve(problem, rule; rng=Xoshiro(1),
                             monitor=LogMonitor(), every=64)
        end

        @testset "records at level -1 with progress keys" begin
            logger = Test.TestLogger(min_level=LogLevel(-1))
            results = with_logger(logger) do
                solve(problem, rule; rng=Xoshiro(1), monitor=LogMonitor(),
                      every=100)
            end
            @test results == plain

            logs = logger.logs
            @test length(logs) == 3
            @test all(l -> l.level == LogLevel(-1), logs)
            @test all(l -> l.message == "Randomized Tukey HSD", logs)
            @test [ l.kwargs[:trials] for l in logs ] == [128, 256, 300]
            @test all(l -> l.kwargs[:planned] == 300, logs)
            @test [ l.kwargs[:progress] for l in logs ] ==
                [128 / 300, 256 / 300, "done"]
            @test length(unique(l.id for l in logs)) == 1
            @test logs[end].kwargs[:pvalues] isa Vector{MonteCarloPValue}
        end

        @testset "every monitor has its own id" begin
            @test LogMonitor().id != LogMonitor().id
        end

        @testset "making one leaves the global generator alone" begin
            Random.seed!(3)
            before = rand()
            Random.seed!(3)
            LogMonitor()
            @test rand() == before
        end
    end
end
