using Logging: @logmsg, LogLevel

"""
    Checkpoint

What a monitor is shown at a checkpoint of a run, with fields

- `trials`: the number of trials done so far;
- `planned`: the number of trials the rule plans;
- `pvalues`: a [`MonteCarloPValue`](@ref) for every pair of treatments, in
  the order of the results of `solve!`;
- `done`: `true` at the last checkpoint, where `trials == planned`.

The checkpoint is a copy: it holds no reference to the run, so a monitor
can look at it and keep it, and cannot change the run or its results.
"""
struct Checkpoint
    trials::Int
    planned::Int
    pvalues::Vector{MonteCarloPValue}
    done::Bool
end

"""
    emit(monitor, checkpoint::Checkpoint)

The method a monitor defines. `solve!` calls it with a [`Checkpoint`](@ref)
every `every` trials (see `init`) and once more at the end of the run, from
the main task and between steps: a monitor need not be thread-safe, and the
results of the run do not depend on what it does. The return value is
ignored. A monitor may throw, which stops the run.

A monitor is any type with this method:

```julia
struct Print end
RandomizedTukeyHSD.emit(::Print, checkpoint) = println(checkpoint.trials)

solve(problem, FixedTrials(10_000); monitor=Print())
```

Whatever it does with the checkpoint (print, plot, send to a logger) is its
own business. It is called at every checkpoint, so a monitor that wants fewer
records keeps its own count.
"""
function emit end

"""
    NoMonitor()

The monitor that does nothing, and the default.
"""
struct NoMonitor end

function emit(::NoMonitor, ::Checkpoint)
    return nothing
end

"""
    LogMonitor()

A monitor that emits a log record at every checkpoint, at level
`LogLevel(-1)`: below `Info`, so the default logger shows nothing. To see the
records, use a logger whose minimum level is lower, or one that renders
progress (the level and the `progress` key are the convention of
ProgressLogging.jl, which TerminalLoggers.jl and the VS Code and Pluto
interfaces show as a progress bar):

```julia
using Logging
with_logger(ConsoleLogger(stderr, LogLevel(-1))) do
    solve(problem, FixedTrials(100_000); monitor=LogMonitor())
end
```

A record has the message "Randomized Tukey HSD" and the keys `trials`,
`planned`, `pvalues` (the vector of the [`Checkpoint`](@ref)) and `progress`
(the fraction done, and `"done"` at the end), and the record's `id` is how a
progress display tells the records of one run from another's, so make a new
`LogMonitor` for every run.

The records carry the p-values, not their intervals: call [`hdi`](@ref) or
[`probability_below`](@ref) on them if you want those.
"""
struct LogMonitor
    id::Base.UUID
end

function LogMonitor()
    return LogMonitor(Base.UUID(rand(Random.RandomDevice(), UInt128)))
end

function emit(monitor::LogMonitor, checkpoint::Checkpoint)
    if checkpoint.done
        progress = "done"
    else
        progress = checkpoint.trials / checkpoint.planned
    end

    @logmsg(
        LogLevel(-1),
        "Randomized Tukey HSD",
        trials=checkpoint.trials,
        planned=checkpoint.planned,
        pvalues=checkpoint.pvalues,
        progress=progress,
        _id=monitor.id,
    )

    return nothing
end
