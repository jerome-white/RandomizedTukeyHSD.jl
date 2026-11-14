# RandomizedTukeyHSD.jl

[![CI](https://github.com/jerome-white/RandomizedTukeyHSD.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/jerome-white/RandomizedTukeyHSD.jl/actions/workflows/CI.yml)
[![Documentation](https://github.com/jerome-white/RandomizedTukeyHSD.jl/actions/workflows/Documentation.yml/badge.svg)](https://github.com/jerome-white/RandomizedTukeyHSD.jl/actions/workflows/Documentation.yml)
[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://jerome-white.github.io/RandomizedTukeyHSD.jl/stable/)
[![Coverage](https://codecov.io/gh/jerome-white/RandomizedTukeyHSD.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/jerome-white/RandomizedTukeyHSD.jl)

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

**Status:** version 0.1.0, the first release.

## Installing

```julia
using Pkg
Pkg.add("RandomizedTukeyHSD")
```

The library needs Julia 1.10 or newer.

## Using the library

```julia
using Random, RandomizedTukeyHSD

# responses: a blocks × treatments matrix
problem = RandomizedTukeyProblem(responses; treatments=["A", "B", "C"])
results = solve(problem, FixedTrials(10_000); rng=Xoshiro(1))
```

`results` has one named tuple per pair of treatments, with the fields
`treatment1`, `treatment2`, `mean1`, `mean2`, `difference` and `pvalue`. It
is a [Tables.jl](https://tables.juliadata.org) table.

## Documentation

The [documentation](https://jerome-white.github.io/RandomizedTukeyHSD.jl/stable/)
has the manual and the reference for every exported name. The manual covers
passing a table, stepping and watching a run, missing responses, the
precision of a p-value, threads and reproducibility, and the known
limitation with floating-point ties. The glossary maps the package's words
(block, treatment, response) to those of information retrieval and machine
learning. Inside Julia, `?RandomizedTukeyHSD` and `?RandomizedTukeyProblem`
show the same text.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the conventions, how to run the
tests and how to build the documentation.

## Citing

To cite the package, use "Cite this repository" on the GitHub page, which
reads [`CITATION.cff`](CITATION.cff). Version 0.1.0 is archived on Zenodo
as [doi:10.5281/zenodo.24220356](https://doi.org/10.5281/zenodo.24220356);
[doi:10.5281/zenodo.24220355](https://doi.org/10.5281/zenodo.24220355) stands
for all versions and resolves to the latest. Please also cite the sources of
the method:

- Carterette, B. A. (2012). Multiple testing in statistical analysis of
  systems-based information retrieval experiments. *ACM Transactions on
  Information Systems*, 30(1), 1-34.
  [doi:10.1145/2094072.2094076](https://doi.org/10.1145/2094072.2094076)
- Sakai, T. (2018). Multiple Comparison Procedures. In *Laboratory
  Experiments in Information Retrieval* (The Information Retrieval Series,
  pp. 59-80). Springer Singapore.
  [doi:10.1007/978-981-13-1199-4_4](https://doi.org/10.1007/978-981-13-1199-4_4)

## Layout

| Path         | Contents                                         |
|--------------|--------------------------------------------------|
| `src/`       | the library                                      |
| `docs/`      | the documentation (Documenter.jl)                |
| `test/`      | the test suite (`] test`) and its references     |
| `examples/`  | `run.jl`, an example script, and its environment |
| `benchmark/` | benchmark suite and the recorded baseline        |
