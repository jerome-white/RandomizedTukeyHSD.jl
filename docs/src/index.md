# RandomizedTukeyHSD.jl

A Julia implementation of the randomized Tukey HSD test for comparing many
treatments (systems, models, methods) over a shared set of blocks (topics,
datasets, folds). The method is described by Carterette
([2012](https://doi.org/10.1145/2094072.2094076)) and advocated by Sakai
([2018](https://doi.org/10.1007/978-981-13-1199-4_4)).

The test needs no normality assumption. In each of `trials` trials the
responses are shuffled across treatments within every block, and the largest
minus the smallest treatment mean is recorded. A pair's p-value is the
fraction of trials whose range is at least the pair's observed difference. It
is not corrected by adding one to the count, so a p-value of 0 means
p < 1/`trials`.

!!! note "Status"
    Version 0.1.0, the first release.

## Installing

```julia
using Pkg
Pkg.add("RandomizedTukeyHSD")
```

The library needs Julia 1.10 or newer and depends only on `CommonSolve`,
`Logging`, `Random`, `SpecialFunctions`, `StatsAPI` and `Tables`.

## A first example

The data are a matrix with blocks in rows and treatments in columns: here four
blocks and three treatments. The names of the parts are in the
[Glossary](@ref).

```@example first
using Random, RandomizedTukeyHSD

responses = [0.10 0.40 0.70
             0.20 0.50 0.60
             0.15 0.45 0.80
             0.25 0.35 0.65]

problem = RandomizedTukeyProblem(responses; treatments=["A", "B", "C"])
results = solve(problem, FixedTrials(10_000); rng=Xoshiro(1))
```

`results` has one named tuple per pair of treatments, in the order (1,2),
(1,3), ..., (n-1,n), with the fields `treatment1`, `treatment2`, `mean1`,
`mean2`, `difference` (`mean1 - mean2`) and `pvalue`. A vector of named tuples
is a [Tables.jl](https://tables.juliadata.org) table, so `DataFrame(results)`
and `CSV.write(io, results)` work without this package depending on either.

```@example first
for r in results
    println(r.treatment1, " vs ", r.treatment2, ": p = ", r.pvalue)
end
```

## The interface

The interface is that of [CommonSolve.jl](https://github.com/SciML/CommonSolve.jl),
the one the SciML packages share: a *problem* says what is solved, a *rule*
says how, and `solve(problem, rule)` is `solve!(init(problem, rule))`. The
verbs `init`, `solve`, `solve!` and `step!` are re-exported (see the
[API reference](@ref)), and they are the same functions, so there is no clash with another package that uses them.

- [`RandomizedTukeyProblem`](@ref)`(responses; treatments)`: the data.
  `responses` has blocks in rows and treatments in columns, at least two
  columns and no `NaN` (see [Missing responses](@ref)). `treatments` is one
  name per column and defaults to the column numbers. A problem is checked
  when it is built, so an invalid one cannot exist.
- [`FixedTrials`](@ref)`(trials)`: the rule, the number of trials (called `B`
  in the literature and in earlier versions of this package).
- `rng`: optional keyword of `solve` and `init`, a random number generator
  (see [Threads and reproducibility](@ref)).

Where to go next:

- [Passing a table](@ref) for a `DataFrame` or any Tables.jl table, and
  [Reading a CSV](@ref).
- [Stepping and watching a run](@ref) to look at a run on the way.
- [How precise is a p-value?](@ref) and
  [Choosing the number of trials](@ref) for the Monte Carlo error.
- [Threads and reproducibility](@ref) and
  [Known limitation: floating-point ties](@ref) for what the results do and do
  not promise.
- [API reference](@ref) for every exported name.

## Citing

To cite the package, use "Cite this repository" on the
[GitHub page](https://github.com/jerome-white/RandomizedTukeyHSD.jl), which
reads its `CITATION.cff`. Please also cite the sources of the method:

- Carterette, B. A. (2012). Multiple testing in statistical analysis of
  systems-based information retrieval experiments. *ACM Transactions on
  Information Systems*, 30(1), 1-34.
  [doi:10.1145/2094072.2094076](https://doi.org/10.1145/2094072.2094076)
- Sakai, T. (2018). Multiple Comparison Procedures. In *Laboratory
  Experiments in Information Retrieval* (The Information Retrieval Series,
  pp. 59-80). Springer Singapore.
  [doi:10.1007/978-981-13-1199-4_4](https://doi.org/10.1007/978-981-13-1199-4_4)
