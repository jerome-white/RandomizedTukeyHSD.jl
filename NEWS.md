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
its result. `value=` is the keyword of the table method (#41), and the two
helpers are unexported. The last row is the words in documentation,
identifiers, tests and fixtures.

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
  `StatsAPI.pvalue`. The result of `randomized_tukey_hsd` is unchanged.
  This adds the dependencies SpecialFunctions and StatsAPI (#55).

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
