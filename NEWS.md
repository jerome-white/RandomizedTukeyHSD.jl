# Release notes

The package is pre-release (`0.1.0-DEV`) and has not been tagged, so every
entry below is under "Unreleased" and renames are made without a
deprecation period. This file records the renames in particular, so that
someone reading an old issue or pull request can find what a term became.
The numbers are issues and pull requests of the repository.

## Unreleased

### Renamed

The vocabulary moved from the information-retrieval words the method came
with to the statistical ones (#38, #42). The README has a table that maps
the words.

| Before                         | Now                           |
|--------------------------------|-------------------------------|
| `B`                            | `trials`                      |
| `systems=`                     | `treatments=`                 |
| `system1`, `system2`           | `treatment1`, `treatment2`    |
| `scores` (the matrix argument) | `responses`                   |
| `value=` (table keyword)       | `response=`                   |
| `scores_matrix`, `wide_scores` | `tidy_matrix`, `wide_matrix`  |
| topic, system, score           | block, treatment, response    |

`B` became `trials` in #39 (and `--B` was kept as an alias of the CLI that
no longer exists); the rest in #42. The first four rows are the public API:
the keyword and the argument of `randomized_tukey_hsd`, and the fields of
its result (the function itself was replaced in #58, below). `value=` is
the keyword of the table method (#41), and the two helpers are unexported.
The last row is the words in documentation, identifiers, tests and
fixtures.

Error messages changed with the words (for example "need at least two
treatments", "responses contain N NaN values"). The reference fixtures in
`test/data` are now `block,treatment,response`, and the stored outputs of
Sakai's code have the header `treatment1,treatment2,difference,p`.

### Added

- The generator is an optional first argument, as in `rand(rng, ...)`
  (#26, #31, #32, #33).
- Tables.jl tables are accepted, wide or tidy, with the names carried by the
  data (#41, #48).
- Results for a fixed generator state are the same at any number of
  threads (#24, #25).
- `MonteCarloPValue(exceeding, trials)` keeps a p-value with the trials it
  came from, and `hdi(p; level=0.95, prior=(1, 1))` and
  `probability_below(p, alpha; prior=(1, 1))` describe its Monte Carlo
  error: a highest density interval of the exact p-value, and the
  probability that it is below `alpha`. `pvalue` extends
  `StatsAPI.pvalue`. The result of `solve` is unchanged.
  This adds the dependencies SpecialFunctions and StatsAPI (#55).

### Added: a run that can be stepped (#57, #61)

`init` now returns a run that holds the counts of the trials so far.
`step!(run, nchunks=1)` advances it by chunks of 64 trials, `trials(run)`
says how many trials are done, and `pvalues(run)` gives a
`MonteCarloPValue` for each pair; `solve!` steps through what is left and
reports as before. Only `FixedTrials` exists, so a step past its trials
throws. The results are unchanged (the output of `benchmark/snapshot.jl` is
byte-identical), and a run keeps one count per pair instead of the ranges of
all the trials. Seeds are still drawn at `init` for all the chunks (#34
changes that).

### Changed: the interface is CommonSolve's (#57, #58)

`randomized_tukey_hsd` is removed. The test is now run with the verbs of
[CommonSolve.jl](https://github.com/SciML/CommonSolve.jl), which are
re-exported:

```julia
problem = RandomizedTukeyProblem(responses; treatments=["A", "B", "C"])
results = solve(problem, FixedTrials(10_000); rng=Xoshiro(1))
```

- `RandomizedTukeyProblem` is the data. Its constructor checks it (at least
  two treatments, one name per column, no `NaN`), with the same errors as
  before. A matrix and a Tables.jl table are the two constructors; a
  table's shape, wide or tidy, is taken from the `block`, `treatment` and
  `response` keywords as before.
- `FixedTrials(trials)` replaces the `trials` keyword.
- **`rng` is now a keyword** (`rng=Xoshiro(1)`), no longer the first
  positional argument, because CommonSolve needs the first positional
  argument to be a type of the package (reverses #26, #31).
- The result is the same vector of named tuples, and the p-values for a
  given generator state are the same as before: the output of
  `benchmark/snapshot.jl` is byte-identical.
- **The Julia floor is 1.10** (it was 1.9): CommonSolve 0.2.14 needs it.
- Adds the dependency CommonSolve.

### Removed

- The command-line interface (`bin/rthsd.jl`) and the helpers only it
  used. `examples/run.jl` shows how to read a CSV from a script (#49,
  #50). The last commit with the CLI is the parent of the first commit of
  #50.

### Changed

- `NaN` in the responses is an error (#22, #23).
- P-values are counted by binary search over the sorted ranges, and the
  trials no longer allocate (#4, #5, #20, #21); results for a fixed
  generator state are the same as before these two changes.
