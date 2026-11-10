# Stepping and watching a run

## Stepping a run

`solve` runs the whole rule. To look at a run on the way, make it with `init`,
advance it with `step!` (in chunks of 64 trials, on all the threads), and read
it with [`trials`](@ref) and [`pvalues`](@ref):

```@example running
using Random, RandomizedTukeyHSD

responses = [0.10 0.40 0.70
             0.20 0.50 0.60
             0.15 0.45 0.80
             0.25 0.35 0.65]
problem = RandomizedTukeyProblem(responses; treatments=["A", "B", "C"])

run = init(problem, FixedTrials(10_000); rng=Xoshiro(1))
step!(run, 10)    # ten chunks, 640 trials
trials(run)       # 640
```

```@example running
pvalues(run)      # a MonteCarloPValue for each pair, out of 640 trials
```

```@example running
solve!(run)       # the rest, then the results, as for `solve`
```

The run keeps one count per pair, not the trials, so its memory does not grow
with the number of trials, and however the chunks are cut into steps the counts
are the same as with one `solve`. A step past the trials the rule plans throws
an `ArgumentError`.

## Watching a run

A *monitor* is shown the p-values so far at regular checkpoints, so you can
watch the Monte Carlo settle. It only looks: it gets a copy, not the run, so it
cannot change the p-values or stop the run (stopping is a rule decided
beforehand, not something to do when an estimate looks good, which biases the
decision). The default monitor, [`NoMonitor`](@ref), does nothing.

```julia
using Logging
with_logger(ConsoleLogger(stderr, LogLevel(-1))) do
    solve(problem, FixedTrials(100_000); monitor=LogMonitor(), every=10_000)
end
```

[`LogMonitor`](@ref) emits a Logging record at every checkpoint, at level
`LogLevel(-1)`, which the default logger does not show; the call above lowers
the level to print them. Loggers that draw progress bars (TerminalLoggers, the
VS Code and Pluto interfaces) show the `progress` key of the records as a bar.
A record carries `trials`, `planned`, the `pvalues` (a [`MonteCarloPValue`](@ref)
per pair, for which [`hdi`](@ref) and [`probability_below`](@ref) give the
uncertainty) and `progress`. `every` is the number of trials between
checkpoints, rounded up to whole chunks of 64, and defaults to 1% of the
trials.

To send the numbers somewhere else, write a monitor: a type with a method of
[`emit`](@ref), called at every checkpoint with a [`Checkpoint`](@ref)
(`trials`, `planned`, `pvalues`, `done`).

```@example running
struct Trace
    trials::Vector{Int}
    smallest::Vector{Float64}
end
Trace() = Trace(Int[], Float64[])

function RandomizedTukeyHSD.emit(trace::Trace, checkpoint)
    push!(trace.trials, checkpoint.trials)
    push!(trace.smallest, minimum(pvalue.(checkpoint.pvalues)))
end

trace = Trace()
solve(problem, FixedTrials(1_000); rng=Xoshiro(1), monitor=trace, every=256)
trace.trials
```

Monitors are called from the main task between steps, so they need not be
thread-safe, and the results are the same with or without one.
