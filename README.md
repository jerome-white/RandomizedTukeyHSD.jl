# RandomizedTukeyHSD.jl

A Julia implementation of the randomized Tukey HSD test for comparing
many treatments (systems, models, methods) over a shared set of blocks
(topics, datasets, folds). The method is described by
Carterette ([2012](https://doi.org/10.1145/2094072.2094076)) and
advocated by Sakai
([2018](https://doi.org/10.1007/978-981-13-1199-4_4)).

The test needs no normality assumption. In each of `trials` trials the
responses are shuffled across treatments within every block, and the
largest minus the smallest treatment mean is recorded. A pair's p-value is
the fraction of trials whose range is at least the pair's observed
difference. It is not corrected by adding one to the count, so a p-value
of 0 means p < 1/`trials`.

**Status:** pre-release (`0.1.0-DEV`), not in the General registry.

## Vocabulary

The data are a randomized block design: one measurement of every treatment
in every block. The package uses the statistical names for the three parts
and maps to the words of the fields it is used in:

| Here        | In information retrieval | In machine learning   | Formerly |
|-------------|--------------------------|-----------------------|----------|
| block       | topic                    | dataset, fold, seed   | topic    |
| treatment   | system                   | model, method         | system   |
| response    | score                    | metric, accuracy      | score    |
| `trials`    | B                        | number of resamples   | `B`      |

The method comes from information retrieval, so the citations above and the
reference tests (which compare with Sakai's code) keep that tool's own words
where they quote it. Earlier versions of this package, its issues and its
pull requests used the words in the last column.

## Installing

```julia
using Pkg
Pkg.add(url="https://github.com/jerome-white/RandomizedTukeyHSD.jl")
```

The library needs Julia 1.10 or newer and depends only on `CommonSolve`,
`Random`, `SpecialFunctions`, `Statistics`, `StatsAPI` and `Tables`.

## Using the library

```julia
using Random, RandomizedTukeyHSD

# responses: a blocks × treatments matrix
problem = RandomizedTukeyProblem(responses; treatments=["A", "B", "C"])
results = solve(problem, FixedTrials(10_000); rng=Xoshiro(1))
```

The interface is that of
[CommonSolve.jl](https://github.com/SciML/CommonSolve.jl), the one the SciML
packages share: a *problem* says what is solved, a *rule* says how, and
`solve(problem, rule)` is `solve!(init(problem, rule))`. The verbs `init`,
`solve`, `solve!` and `step!` are re-exported, and they are the same
functions, so there is no clash with another package that uses them.

- `RandomizedTukeyProblem(responses; treatments)`: the data. `responses`
  has blocks in rows and treatments in columns, at least two columns and no
  `NaN` (see [Missing responses](#missing-responses)). `treatments` is one
  name per column and defaults to the column numbers. A problem is checked
  when it is built, so an invalid one cannot exist.
- `FixedTrials(trials)`: the rule, the number of trials (called `B` in the
  literature and in earlier versions of this package).
- `rng`: optional keyword of `solve` and `init`, a random number generator
  (see [Threads and reproducibility](#threads-and-reproducibility)).

`results` has one named tuple per pair of treatments, in the order
(1,2), (1,3), ..., (n-1,n), with the fields `treatment1`, `treatment2`,
`mean1`, `mean2`, `difference` (`mean1 - mean2`) and `pvalue`. A vector of named
tuples is a [Tables.jl](https://tables.juliadata.org) table, so
`DataFrame(results)` and `CSV.write(io, results)` work without this
package depending on either. The docstrings (`?RandomizedTukeyProblem`,
`?solve!`) list the errors it throws.

### Stepping a run

`solve` runs the whole rule. To look at a run on the way, make it with
`init`, advance it with `step!` (in chunks of 64 trials, on all the
threads), and read it with `trials` and `pvalues`:

```julia
run = init(problem, FixedTrials(10_000); rng=Xoshiro(1))
step!(run, 10)    # ten chunks, 640 trials
trials(run)       # 640
pvalues(run)      # a MonteCarloPValue for each pair, out of 640 trials
solve!(run)       # the rest, then the results, as for `solve`
```

The run keeps one count per pair, not the trials, so its memory does not
grow with the number of trials, and however the chunks are cut into steps
the counts are the same as with one `solve`. A step past the trials the rule
plans throws an `ArgumentError`.

### Watching a run

A *monitor* is shown the p-values so far at regular checkpoints, so you can
watch the Monte Carlo settle. It only looks: it gets a copy, not the run, so
it cannot change the p-values or stop the run (stopping is a rule decided
beforehand, not something to do when an estimate looks good, which biases the
decision). The default monitor does nothing.

```julia
using Logging
with_logger(ConsoleLogger(stderr, LogLevel(-1))) do
    solve(problem, FixedTrials(100_000); monitor=LogMonitor(), every=10_000)
end
```

`LogMonitor` emits a Logging record at every checkpoint, at level
`LogLevel(-1)`, which the default logger does not show; the call above
lowers the level to print them. Loggers that draw progress bars
(TerminalLoggers, the VS Code and Pluto interfaces) show the `progress` key of
the records as a bar. A record carries `trials`, `planned`, the `pvalues` (a
`MonteCarloPValue` per pair, for which `hdi` and `probability_below` give the
uncertainty) and `progress`. `every` is the number of trials between
checkpoints, rounded up to whole chunks of 64, and defaults to 1% of the
trials.

To send the numbers somewhere else, write a monitor: a type with a method of
`emit`, called at every checkpoint with a `Checkpoint` (`trials`, `planned`,
`pvalues`, `done`).

```julia
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
solve(problem, FixedTrials(100_000); monitor=trace)
```

Monitors are called from the main task between steps, so they need not be
thread-safe, and the results are the same with or without one.

### Passing a table

Names travel with the data when you build the problem from a
[Tables.jl](https://tables.juliadata.org) table, such as a `DataFrame`;
there is no `treatments` argument then. Which shape the table has is told by
the column keywords, each a column name as a `Symbol` or a `String`. There is
one constructor for both shapes.

```julia
rule = FixedTrials(10_000)

# wide: each column is a treatment, each row a block
solve(RandomizedTukeyProblem(df), rule; rng=Xoshiro(1))
# the same, leaving out a column that identifies the rows
solve(RandomizedTukeyProblem(df; block=:dataset), rule; rng=Xoshiro(1))

# tidy: one row per block and treatment
problem = RandomizedTukeyProblem(df; block=:dataset, treatment=:model,
                                 response=:accuracy)
solve(problem, rule; rng=Xoshiro(1))
```

Wide names the treatments by the column names, as the table gives them
(`Symbol`s). Tidy names them by the values of the `treatment` column, and
takes blocks and treatments in the order they first appear. A missing
response, or a block and treatment with no row, is rejected like a `NaN`. A
real matrix takes the matrix constructor above. The library does not
depend on DataFrames; any table works.

## Reading a CSV

There is no command-line tool: you call the function from your own Julia
script, as with other Julia packages. `examples/run.jl` is a ten-line
example that reads a CSV with CSV.jl and DataFrames.jl and writes the
results as CSV; copy it and change the column names to match your file
(it expects `block`, `treatment` and `response`).

```bash
julia --project=examples -e 'using Pkg; Pkg.instantiate()'
julia --project=examples examples/run.jl data.csv 100000 > results.csv
```

The `examples` environment needs Julia 1.11 or newer, because
`examples/Project.toml` points at the library with a `[sources]` path
entry. The script takes the path, the number of trials, and an optional
seed. It reads a tidy file (one row per block and treatment); for a wide
one (one column per treatment), drop the column keywords from the call, as
described under [Passing a table](#passing-a-table).

## Missing responses

A missing or `NaN` response makes the test meaningless, so the library
rejects `NaN` with an error that says how many there are. Each trial
shuffles the `NaN` into some treatment, so every trial's range is `NaN`
and every p-value is meaningless, including those of pairs that do not
involve the treatment it came from.

What to do is your decision, and it depends on why the responses are missing.
The sound option is to keep only the blocks that have a response for every
treatment (complete cases). The test is then exactly valid on those blocks,
because every treatment is still averaged over the same blocks. That is
right for a block that is undefined for all treatments (for example, a
dataset where the metric is undefined for every model, or, in information
retrieval, a topic with no relevant documents), but it flatters a
treatment whose failures are dropped. Averaging each treatment over only
its own blocks (`nanmean`) is not offered: it compares treatments on
different blocks, which defeats the point of the test.

With a DataFrame, complete cases are a line or two:

```julia
# wide: one row per block
df = dropmissing(df)                                   # empty cells
df = filter(row -> all(!isnan, row[Not(:block)]), df)  # NaN; :block is the id

# tidy: one row per block and treatment; also drops blocks with a missing row
ntreatments = length(unique(df.treatment))
usable(x) = !ismissing(x) && !isnan(x)
df = DataFrame(filter(groupby(df, :block)) do rows
    nrow(rows) == ntreatments && all(usable, rows.response)
end)
```

## How precise is a p-value?

A p-value from `trials` trials estimates the exact permutation p-value
(every within-block arrangement counted), and more trials sharpen the
estimate without changing the data. `MonteCarloPValue` holds a p-value
together with the number of trials it came from, and `hdi` and
`probability_below` describe its Monte Carlo error. The result of
`solve` is unchanged; build the type from a result's `pvalue` and
`trials`, or from the counts.

```julia
problem = RandomizedTukeyProblem(responses)
results = solve(problem, FixedTrials(10_000); rng=Xoshiro(1))
p = MonteCarloPValue(results[2].pvalue, 10_000)

pvalue(p)                         # the p-value, exceeding / trials
hdi(p)                            # (lower, upper) for the exact p-value
hdi(p; level=0.9)
hdi(p; prior=(0.5, 0.5))          # Jeffreys' prior instead of the uniform
probability_below(p, 0.05)        # probability the exact p-value < 0.05

MonteCarloPValue(49, 1000)        # from the counts: 49 of 1000 trials
```

- The trials that reached a pair's difference are binomial in the exact
  p-value. A `prior=(a, b)` is a Beta(`a`, `b`) distribution for it, uniform
  by default, and its distribution afterwards is a Beta distribution too.
  `hdi` is that distribution's highest density interval: the shortest one
  holding `level` (0.95 by default) of the probability. Read it as "given
  these trials and the prior, the exact p-value is in here with 95%
  probability".
- It is a Bayesian credible interval, not a confidence interval, and has no
  coverage guarantee. The prior is a choice and matters only for small
  counts; at zero exceedances the upper end is 3.0 / `trials` for the
  uniform prior and 1.9 / `trials` for Jeffreys'. Only Beta priors are
  supported.
- A p-value of 0 gives an interval from 0 to about `3 / trials`: the
  trials rule out little more than that.
- `probability_below(p, alpha)` is the chance that the exact p-value is below
  `alpha`, which shows whether more trials could put the p-value on the other
  side of it. For an observed 0.049 it is 0.52 at 1000 trials, 0.67 at
  10 000 and 0.93 at 100 000. The library takes no `alpha` of its own; the
  decision is yours.
- The interval covers the Monte Carlo error only: not the assumptions of the
  test, the floating-point ties below, or that many pairs are tested (the
  range statistic already accounts for that). The intervals of different
  pairs are not simultaneous.
- Decide `trials` and the seed before looking at the results. Running again
  until a p-value falls below a level, or until its interval does, is not a
  valid procedure; the interval does not make it one.
- `pvalue` is the generic function of
  [StatsAPI](https://github.com/JuliaStats/StatsAPI.jl), which the Julia
  statistics packages share, so it is the same function after
  `using HypothesisTests`. `hdi` is not `confint`, which is a
  confidence interval.

## Threads and reproducibility

Start Julia with more threads to use them (`-t N`, or `-t auto`):

```bash
julia -t auto --project=examples examples/run.jl data.csv 100000
```

Every trial has its own random stream, which depends only on a base seed and
on the number of the trial. The base seed is drawn from the random number
generator you pass as the `rng` keyword (the global one if left out) when
the run is made. So with a fixed `rng` state the p-values are the same at
any thread count, and however the trials are cut into chunks for the
threads:

```julia
using Random
problem = RandomizedTukeyProblem(responses)
solve(problem, FixedTrials(100_000); rng=Xoshiro(1))
```

Seeding the global generator (`Random.seed!(1)`) and leaving `rng` out
does the same. The example script takes a seed as its third argument.

What this does and does not promise:

- The same seed, `trials`, responses and Julia version give the same
  p-values on any machine and thread count. Across Julia versions the
  random streams (`Xoshiro`, `shuffle!`) are not guaranteed to stay the
  same.
- The chunk size (64 trials per task) only schedules the work and is not
  part of the result. The number of random numbers a trial draws and the
  way a trial's stream is derived from the seed are, so they may change
  between package versions. Record the package version with the seed.
- It is a safeguard for an exact re-run, not for the conclusions. A
  p-value has a Monte Carlo error of about `sqrt(p(1 - p) / trials)`
  (0.0007 for p = 0.05 and `trials` = 100 000; see
  [How precise is a p-value?](#how-precise-is-a-p-value)), so choose
  `trials` large enough that the decisions do not depend on the seed, and
  record the seed, `trials` and versions with the results.

## Known limitation: floating-point ties

A trial counts when its range is `>=` the observed difference. When a
permuted range equals the observed difference mathematically but differs
from it in the last bit, which can happen with responses on a regular grid
such as multiples of 0.05, that trial is not counted. P-values can then be
slightly too small. There is deliberately no tolerance in the library. In
the 4-block example in `test/data/tiny.csv` the pair (A, B) converges to
0.3935 where the mathematical value is 0.4028, which Sakai's Discpower
gives because it rounds ranges to six decimals. Responses with many distinct
values (most real metrics) are far less likely to be affected. The effect
is recorded in `test/reference.jl` (issue #17).

## How it is checked

`] test` runs the suite, and CI runs it on Julia 1.10 and the latest
release at one and four threads. Besides unit tests, the library is
compared with the exact p-values (every within-block arrangement
enumerated) and with the output of Sakai's own implementation, Discpower,
on problems small enough to enumerate. See `test/reference/README.md`.

`benchmark/` holds the benchmark suite, the baseline measured before the
performance work, and the tables for each change.

## Layout

| Path         | Contents                                         |
|--------------|--------------------------------------------------|
| `src/`       | the library                                      |
| `test/`      | the test suite (`] test`) and its references     |
| `examples/`  | `run.jl`, an example script, and its environment |
| `benchmark/` | benchmark suite and the recorded baseline        |
