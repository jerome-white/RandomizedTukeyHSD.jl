# RandomizedTukeyHSD.jl

A Julia implementation of the randomized Tukey HSD test for comparing
many systems over a shared set of topics. The method is described by
Carterette ([2012](https://doi.org/10.1145/2094072.2094076)) and
advocated by Sakai
([2018](https://doi.org/10.1007/978-981-13-1199-4_4)).

The test needs no normality assumption. In each of B trials the scores
are shuffled across systems within every topic, and the largest minus
the smallest system mean is recorded. A pair's p-value is the fraction
of trials whose range is at least the pair's observed difference.

**Status:** under construction; see the open issues for the plan.

## Using the library

```julia
using RandomizedTukeyHSD

# scores: a topics × systems matrix
results = randomized_tukey_hsd(scores; B=10_000, systems=["A", "B", "C"])
```

`results` has one named tuple per pair of systems with the fields
`system1`, `system2`, `mean1`, `mean2`, `difference` and `pvalue`.

## Layout

| Path         | Contents                                      |
|--------------|-----------------------------------------------|
| `src/`       | the library                                   |
| `test/`      | the test suite (`] test`)                     |
| `bin/`       | `rthsd.jl`, the CLI, with its own environment |
| `benchmark/` | benchmark suite and the recorded baseline     |

## Running the CLI

Input is tidy CSV on stdin with `topic`, `system` and `score` columns.
The CLI needs Julia 1.11 or newer, because `bin/Project.toml` points at
the library with a `[sources]` path entry.

```bash
julia --project=bin -e 'using Pkg; Pkg.instantiate()'
julia --project=bin bin/rthsd.jl --B 10000 < scores.csv
```

A topic with a missing or `NaN` score in any system makes the test
meaningless, so by default the CLI stops with an error. `--missing drop`
removes those topics for every system (complete cases) and says how many
it removed. Whether that is appropriate depends on why the scores are
missing: it is sound for a topic that is undefined for all systems, but
flatters a system whose failures are dropped.

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
