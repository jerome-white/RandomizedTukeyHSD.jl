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

| Path       | Contents                                        |
|------------|-------------------------------------------------|
| `src/`     | the library                                     |
| `test/`    | the test suite (`] test`)                       |
| `bin/`     | `rthsd.jl`, the CLI, with its own environment   |

## Running the CLI

Input is tidy CSV on stdin with `topic`, `system` and `score` columns.
The CLI needs Julia 1.11 or newer, because `bin/Project.toml` points at
the library with a `[sources]` path entry.

```bash
julia --project=bin -e 'using Pkg; Pkg.instantiate()'
julia --project=bin bin/rthsd.jl --B 10000 < scores.csv
```

Add `-t N` (or `-t auto`) to use more threads. The threading design is
still being reworked (#6).
