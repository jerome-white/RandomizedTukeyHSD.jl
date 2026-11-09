# Contributing

This file records the conventions that contributors, human or not, are
expected to follow. It is short on purpose: where a convention is the
standard one in the Julia ecosystem it is named, not re-explained.

## Running the tests

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

or `] test` from the package environment. The suite takes under a minute.
Run it this way, or with `julia --check-bounds=yes`, which is what
`Pkg.test` passes: the floating-point ties test in `test/reference.jl`
(issue #17) gives different values without that flag, so a bare
`include("test/runtests.jl")` can report failures that CI does not.
It starts with [Aqua.jl](https://github.com/JuliaTesting/Aqua.jl), the
community's package-quality checks (method ambiguities, undefined exports,
stale dependencies, compat bounds, type piracy and others), run with all
checks at their defaults. If a check has to be relaxed, pass that one
keyword in `test/aqua.jl` and say why in a comment.

## Dependencies and compat

`[compat]` in a `Project.toml` states which versions of each dependency the
package works with. Users and the Julia resolver rely on it, so it is a
promise, and these rules keep the promise honest.

**Two projects.**

- `Project.toml` lists only what the package needs at run time.
- `test/Project.toml` lists every package the tests load directly: `Test`,
  `Aqua`, `DataFrames`, and also the run-time dependencies the tests use
  (`Random`, `Tables`, ...), because the package's own dependencies are not
  loadable from test code unless the test project lists them. Do not use
  `[extras]` and `[targets]`; that is the older form.

**Every entry gets a compat bound.** Each package in `[deps]` of either
project has an entry in that project's `[compat]`, and so does `julia` in
the root project. This includes standard libraries (`"1"`). The General
registry requires an upper-bounded entry only for non-standard-library
dependencies, but Aqua's compat check requires all of them, and one
uniform rule is easier to follow.

**Form of a bound.** Use the major series: `"2"` for a package at 2.x, and
the minor series for a 0.x package (`"0.2"`). Never `">=1"` or `"0"`: the
registry rejects bounds with no upper limit.

**The lower bound is a tested claim.** The `downgrade` job in
`.github/workflows/CI.yml` resolves every dependency to the lowest version
its bound allows and runs the tests on Julia 1.10. The other jobs always
install the newest allowed versions, so they cannot catch a bound that is
too loose.

- A lower bound means "the oldest version known to pass the tests", not
  the oldest version that might work. Do not claim a version the job has
  not run.
- If the `downgrade` job fails, the lower bound is too low. Raise it to the
  oldest version that passes, in the same pull request, and say why in the
  commit message. The usual causes are a function the package uses that
  the old version lacks (the first run of the job found this for
  `CommonSolve.step!` and `StatsAPI.pvalue`) and a numerical difference
  in the old version.
- If you change the code so that it needs a feature of a newer version of
  a dependency, raise the lower bound in the same commit.
- Raising a lower bound is an ordinary change, not a breaking one: users
  of older versions of the dependency can stay on an older version of this
  package. Record it in `NEWS.md` under the release that contains it.

**Widening an upper bound.** When a dependency releases a new major
version, test the package against it first, then widen the bound
(`"2"` becomes `"2, 3"`) in its own commit. Do not widen a bound that has
not been tested.

**Adding a dependency.** Add it to `[deps]` and `[compat]` of the right
project in one commit, then run the tests, which run Aqua. Prefer
dependencies that are registered in General; the registry cannot accept a
package that depends on an unregistered one.

**The Julia floor** is the `julia` entry in the root `Project.toml` (now
1.10), and CI tests it. Raising it is a user-visible change: record it in
`NEWS.md`.
