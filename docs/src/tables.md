# Passing a table

Names travel with the data when you build the problem from a
[Tables.jl](https://tables.juliadata.org) table, such as a `DataFrame`; there
is no `treatments` argument then. Which shape the table has is told by the
column keywords, each a column name as a `Symbol` or a `String`. There is one
constructor for both shapes.

The examples use a named tuple of vectors, which is a table; a `DataFrame`
works the same way. The library does not depend on DataFrames; any table
works.

```@example tables
using Random, RandomizedTukeyHSD

# wide: each column is a treatment, each row a block
wide = (A=[0.10, 0.20, 0.15, 0.25],
        B=[0.40, 0.50, 0.45, 0.35],
        C=[0.70, 0.60, 0.80, 0.65])
rule = FixedTrials(10_000)
solve(RandomizedTukeyProblem(wide), rule; rng=Xoshiro(1))
```

When the table has a column that identifies the rows, name it with `block` and
it is left out of the treatments:

```@example tables
labelled = merge((dataset=["d1", "d2", "d3", "d4"],), wide)
solve(RandomizedTukeyProblem(labelled; block=:dataset), rule; rng=Xoshiro(1))
```

A tidy table has one row per block and treatment:

```@example tables
tidy = (dataset=repeat(["d1", "d2", "d3", "d4"], 3),
        model=repeat(["A", "B", "C"], inner=4),
        accuracy=[wide.A; wide.B; wide.C])
problem = RandomizedTukeyProblem(tidy; block=:dataset, treatment=:model,
                                 response=:accuracy)
solve(problem, rule; rng=Xoshiro(1))
```

Wide names the treatments by the column names, as the table gives them
(`Symbol`s). Tidy names them by the values of the `treatment` column, and takes
blocks and treatments in the order they first appear. A missing response, or a
block and treatment with no row, is rejected like a `NaN`. A real matrix takes
the matrix constructor.

## Reading a CSV

There is no command-line tool: you call the function from your own Julia
script, as with other Julia packages. `examples/run.jl` in the
[repository](https://github.com/jerome-white/RandomizedTukeyHSD.jl/tree/master/examples)
is a ten-line example that reads a CSV with CSV.jl and DataFrames.jl and
writes the results as CSV; copy it and change the column names to match your
file (it expects `block`, `treatment` and `response`).

```bash
julia --project=examples -e 'using Pkg; Pkg.instantiate()'
julia --project=examples examples/run.jl data.csv 100000 > results.csv
```

The `examples` environment needs Julia 1.11 or newer, because
`examples/Project.toml` points at the library with a `[sources]` path entry.
The script takes the path, the number of trials, and an optional seed. It
reads a tidy file (one row per block and treatment); for a wide one (one
column per treatment), drop the column keywords from the call, as described
under [Passing a table](@ref).
