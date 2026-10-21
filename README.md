# RandomizedTukeyHSD.jl

A Julia implementation of the randomized Tukey HSD test for comparing
many systems over a shared set of topics. The method is described by
Carterette ([2012](https://doi.org/10.1145/2094072.2094076)) and
advocated by Sakai
([2018](https://doi.org/10.1007/978-981-13-1199-4_4)).

The test needs no normality assumption. In each of B trials the scores
are shuffled across systems within every topic, and the largest minus
the smallest system mean is recorded. A pair's p-value is the fraction
of trials whose range is at least the pair's observed difference. It is
not corrected by adding one to the count, so a p-value of 0 means
p < 1/B.

**Status:** pre-release (`0.1.0-DEV`), not in the General registry.

## Installing

```julia
using Pkg
Pkg.add(url="https://github.com/jerome-white/RandomizedTukeyHSD.jl")
```

The library needs Julia 1.9 or newer and depends only on `Random` and
`Statistics`.

## Using the library

```julia
using Random, RandomizedTukeyHSD

# scores: a topics × systems matrix
results = randomized_tukey_hsd(Xoshiro(1), scores; B=10_000,
                               systems=["A", "B", "C"])
```

- `scores`: topics in rows, systems in columns. It must have at least two
  columns and no `NaN` (see [Missing scores](#missing-scores)).
- `B`: the number of trials, required.
- `systems`: one name per column; defaults to the column numbers.
- `rng`: optional first argument, a random number generator
  (see [Threads and reproducibility](#threads-and-reproducibility)).

`results` has one named tuple per pair of systems, in the order
(1,2), (1,3), ..., (n-1,n), with the fields `system1`, `system2`, `mean1`,
`mean2`, `difference` (`mean1 - mean2`) and `pvalue`. A vector of named
tuples is a [Tables.jl](https://tables.juliadata.org) table, so
`DataFrame(results)` and `CSV.write(io, results)` work without this
package depending on either. The docstring (`?randomized_tukey_hsd`) lists
the errors it throws.

## Running the CLI

`bin/rthsd.jl` reads scores and writes the results as CSV. It needs Julia
1.11 or newer, because `bin/Project.toml` points at the library with a
`[sources]` path entry.

```bash
julia --project=bin -e 'using Pkg; Pkg.instantiate()'
julia --project=bin bin/rthsd.jl --B 10000 < scores.csv > results.csv
```

**Input** is tidy CSV on stdin with `topic`, `system` and `score`
columns, one row per topic and system:

```
topic,system,score
t1,A,0.10
t1,B,0.40
t2,A,0.20
...
```

**Output** is CSV on stdout with the columns `S1_name`, `S2_name`,
`S1_mean`, `S2_mean`, `difference` and `pvalue`, one row per pair. The
settings used are logged to stderr.

| Option        | Meaning                                         |
|---------------|-------------------------------------------------|
| `--B N`       | number of trials; required                      |
| `--seed N`    | seed for the generator; otherwise runs differ   |
| `--missing M` | `error` (default) or `drop`; see below          |

## Missing scores

A missing or `NaN` score makes the test meaningless, and the library
rejects `NaN`. Each trial shuffles the `NaN` into some system, so every
trial's range is `NaN` and every p-value is meaningless, including those
of pairs that do not involve the system it came from.

By default the CLI stops with an error naming how many topics are
affected. `--missing drop` removes every such topic for all systems
(complete cases) and says how many it removed. The test is then exactly
valid on the remaining topics, because every system is still averaged over
the same topics. Whether dropping is appropriate depends on why the
scores are missing: it is sound for a topic that is undefined for all
systems (for example, a topic with no relevant documents), but it flatters
a system whose failures are dropped. Averaging each system over only its
own topics (`nanmean`) is deliberately not offered: it compares systems on
different topics, which defeats the point of the test.

## Threads and reproducibility

Add `-t N` (or `-t auto`) to use more threads:

```bash
julia -t auto --project=bin bin/rthsd.jl --B 100000 < scores.csv
```

The trials are cut into chunks of 64, whichever number of threads is used.
Each chunk gets its own seed, drawn up front from the random number
generator you pass first, as in `rand(rng, ...)` (the global one if left
out), and its own buffers. So with a fixed `rng` state the p-values are
the same at any thread count:

```julia
using Random
randomized_tukey_hsd(Xoshiro(1), scores; B=100_000)
```

Seeding the global generator (`Random.seed!(1)`) and leaving it out does
the same. The CLI takes `--seed`, and prints the settings it used (`B`,
the seed) to stderr:

```bash
julia --project=bin bin/rthsd.jl --B 100000 --seed 1 < scores.csv
```

Without `--seed` the generator is not seeded and each run differs.

What this does and does not promise:

- The same seed, `B`, scores and Julia version give the same p-values on
  any machine and thread count. Across Julia versions the random streams
  (`Xoshiro`, `shuffle!`) are not guaranteed to stay the same.
- The chunk size (64, an internal default that is not a public parameter)
  is part of the result: changing it, or the number of random numbers a
  trial draws, changes the output for a fixed seed, so it may change
  between package versions. Record the package version with the seed.
- It is a safeguard for an exact re-run, not for the conclusions. A
  p-value has a Monte Carlo error of about `sqrt(p(1 - p) / B)` (0.0007
  for p = 0.05 and `B` = 100 000), so choose `B` large enough that the
  decisions do not depend on the seed, and record the seed, `B` and
  versions with the results.

## Known limitation: floating-point ties

A trial counts when its range is `>=` the observed difference. When a
permuted range equals the observed difference mathematically but differs
from it in the last bit, which can happen with scores on a regular grid
such as multiples of 0.05, that trial is not counted. P-values can then be
slightly too small. There is deliberately no tolerance in the library. In
the 4-topic example in `test/data/tiny.csv` the pair (A, B) converges to
0.3935 where the mathematical value is 0.4028, which Sakai's Discpower
gives because it rounds ranges to six decimals. Scores with many distinct
values (most real metrics) are far less likely to be affected. The effect
is recorded in `test/reference.jl` (issue #17).

## How it is checked

`] test` runs the suite, and CI runs it on Julia 1.9 and the latest
release at one and four threads. Besides unit tests, the library is
compared with the exact p-values (every within-topic arrangement
enumerated) and with the output of Sakai's own implementation, Discpower,
on problems small enough to enumerate. See `test/reference/README.md`.

`benchmark/` holds the benchmark suite, the baseline measured before the
performance work, and the tables for each change.

## Layout

| Path         | Contents                                      |
|--------------|-----------------------------------------------|
| `src/`       | the library                                   |
| `test/`      | the test suite (`] test`) and its references  |
| `bin/`       | `rthsd.jl`, the CLI, with its own environment |
| `benchmark/` | benchmark suite and the recorded baseline     |
