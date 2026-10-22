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

The library needs Julia 1.9 or newer and depends only on `Random`,
`SpecialFunctions`, `Statistics` and `Tables`.

## Using the library

```julia
using Random, RandomizedTukeyHSD

# responses: a blocks × treatments matrix
results = randomized_tukey_hsd(Xoshiro(1), responses; trials=10_000,
                               treatments=["A", "B", "C"])
```

- `responses`: blocks in rows, treatments in columns. It must have at
  least two columns and no `NaN` (see
  [Missing responses](#missing-responses)).
- `trials`: the number of trials, required (called `B` in the literature
  and in earlier versions of this package).
- `treatments`: one name per column; defaults to the column numbers.
- `rng`: optional first argument, a random number generator
  (see [Threads and reproducibility](#threads-and-reproducibility)).

`results` has one named tuple per pair of treatments, in the order
(1,2), (1,3), ..., (n-1,n), with the fields `treatment1`, `treatment2`,
`mean1`, `mean2`, `difference` (`mean1 - mean2`) and `pvalue`. A vector of named
tuples is a [Tables.jl](https://tables.juliadata.org) table, so
`DataFrame(results)` and `CSV.write(io, results)` work without this
package depending on either. The docstring (`?randomized_tukey_hsd`) lists
the errors it throws.

### Passing a table

Names travel with the data when you pass a
[Tables.jl](https://tables.juliadata.org) table, such as a `DataFrame`;
there is no `treatments` argument then. Which shape the table has is told by
the column keywords, each a column name as a `Symbol` or a `String`.

```julia
# wide: each column is a treatment, each row a block
randomized_tukey_hsd(Xoshiro(1), df; trials=10_000)
# the same, leaving out a column that identifies the rows
randomized_tukey_hsd(Xoshiro(1), df; trials=10_000, block=:dataset)

# tidy: one row per block and treatment
randomized_tukey_hsd(Xoshiro(1), df; trials=10_000,
                     block=:dataset, treatment=:model, response=:accuracy)
```

Wide names the treatments by the column names, as the table gives them
(`Symbol`s). Tidy names them by the values of the `treatment` column, and
takes blocks and treatments in the order they first appear. A missing
response, or a block and treatment with no row, is rejected like a `NaN`. A
real matrix still takes the matrix method above. The library does not
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
estimate without changing the data. `pvalue_interval` and `probability_below`
describe that Monte Carlo error from a result's `pvalue` and the number of
`trials`; the result itself is unchanged.

```julia
results = randomized_tukey_hsd(Xoshiro(1), responses; trials=10_000)
p = results[2].pvalue

pvalue_interval(p, 10_000)             # (lower, upper) for the exact p-value
pvalue_interval(p, 10_000; level=0.9)
probability_below(p, 10_000, 0.05)     # probability the exact p-value < 0.05
```

- The trials that reached a pair's difference are binomial in the exact
  p-value. With a uniform prior on it, its distribution afterwards is a Beta
  distribution, and the interval is that distribution's highest density
  interval: the shortest one holding `level` (0.95 by default) of the
  probability. Read it as "given these trials, the exact p-value is in here
  with 95% probability".
- It is a Bayesian credible interval, not a confidence interval, and has no
  coverage guarantee. The uniform prior is a choice; it matters only for
  small counts.
- A p-value of 0 gives an interval from 0 to about `3 / trials`: the
  trials rule out little more than that.
- `probability_below(p, trials, alpha)` is the chance that more trials would
  put the p-value on the other side of `alpha`, when it is near it. For an
  observed 0.049 it is 0.52 at 1000 trials, 0.67 at 10 000 and 0.93 at
  100 000. The library takes no `alpha` of its own; the decision is yours.
- The interval covers the Monte Carlo error only: not the assumptions of the
  test, the floating-point ties below, or that many pairs are tested (the
  range statistic already accounts for that). The intervals of different
  pairs are not simultaneous.
- Decide `trials` and the seed before looking at the results. Running again
  until a p-value falls below a level, or until its interval does, is not a
  valid procedure; the interval does not make it one.

## Threads and reproducibility

Start Julia with more threads to use them (`-t N`, or `-t auto`):

```bash
julia -t auto --project=examples examples/run.jl data.csv 100000
```

The trials are cut into chunks of 64, whichever number of threads is used.
Each chunk gets its own seed, drawn up front from the random number
generator you pass first, as in `rand(rng, ...)` (the global one if left
out), and its own buffers. So with a fixed `rng` state the p-values are
the same at any thread count:

```julia
using Random
randomized_tukey_hsd(Xoshiro(1), responses; trials=100_000)
```

Seeding the global generator (`Random.seed!(1)`) and leaving `rng` out
does the same. The example script takes a seed as its third argument.

What this does and does not promise:

- The same seed, `trials`, responses and Julia version give the same
  p-values on any machine and thread count. Across Julia versions the
  random streams (`Xoshiro`, `shuffle!`) are not guaranteed to stay the
  same.
- The chunk size (64, an internal default that is not a public parameter)
  is part of the result: changing it, or the number of random numbers a
  trial draws, changes the output for a fixed seed, so it may change
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

`] test` runs the suite, and CI runs it on Julia 1.9 and the latest
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
