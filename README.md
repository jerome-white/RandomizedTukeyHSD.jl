# RandomizedTukeyHSD.jl

A Julia implementation of the randomized Tukey HSD test for comparing
many systems over a shared set of topics, as described by Carterette
(2012) and advocated by Tetsuya Sakai in [*Laboratory Experiments in
Information Retrieval*](http://sakailab.com/leirbook/).

The test needs no normality assumption. In each of B trials the scores
are shuffled across systems within every topic, and the largest minus
the smallest system mean is recorded. A pair's p-value is the fraction
of trials whose range is at least the pair's observed difference.

**Status:** under construction. The command-line script in `bin/` works
and the library module is empty; see the open issues for the plan.

## Layout

| Path       | Contents                                        |
|------------|-------------------------------------------------|
| `src/`     | the library                                     |
| `test/`    | the test suite (`] test`)                       |
| `bin/`     | `rthsd.jl`, the CLI, with its own environment   |

## Running the CLI

Input is tidy CSV on stdin with `topic`, `system` and `score` columns.

```bash
julia --project=bin -e 'using Pkg; Pkg.instantiate()'
julia --project=bin bin/rthsd.jl --B 10000 < scores.csv
```

The script is currently single-threaded only. Running it with more than
one thread (`-t 2`, `-t auto`) crashes with a `BoundsError`, because it
indexes per-thread state by `threadid()`, which on recent Julia versions
can exceed `nthreads()`. This is tracked in #6.
