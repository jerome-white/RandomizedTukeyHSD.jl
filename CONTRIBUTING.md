# Contributing

This file records the conventions that contributors, human or not, are
expected to follow. It is short on purpose: where a convention is the
standard one in the Julia ecosystem it is named, not re-explained.

## Making a change

These rules apply to every contributor, human or agent.

- **Every change has an issue**, however small. Describe the problem and
  the intended change fully enough that someone without your context can
  act on it. Do not shorten.
- **One issue, one branch, one pull request.** Branch from `master` as
  `issue-N-short-slug`. The pull request description starts with
  `Closes #N` and says what was verified and what was not.
- **Commit at each logical step**, not once at the end. A commit message
  has a summary line, a body that says what changed and why (it is part of
  the documentation: `git blame` should answer "why is it like this"), and
  ends with `Refs #N`.
- **The maintainer merges.** Do not push to `master`, and do not merge your
  own pull request.
- **Run the tests, and build the documentation if you touched it,** before
  you open the pull request (see below). Do not start a job that runs for
  more than a minute or two inside an agent session: give the maintainer the
  command to run.
- **Changes to the behaviour of `src/`** need the maintainer's agreement,
  recorded on the issue, before they are made. Performance work, style and
  docstrings are covered by the issue itself. Tests are yours to change.

## Style

- Lines are at most 80 columns, and code is ASCII.
- Check an argument with an `if` block that throws, not with
  `cond || throw(...)`.
- No module-level mutable globals.
- A helper used once is written inline, not as a function.
- Follow the style of the file you are editing. (A formatter is not yet
  enforced.)

## Running the tests

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

or `] test` from the package environment. The suite takes under a minute.
It starts with [Aqua.jl](https://github.com/JuliaTesting/Aqua.jl), the
community's package-quality checks (method ambiguities, undefined exports,
stale dependencies, compat bounds, type piracy and others), run with all
checks at their defaults. If a check has to be relaxed, pass that one
keyword in `test/aqua.jl` and say why in a comment.

## Documentation

The documentation is built with [Documenter.jl](https://documenter.juliadocs.org)
from `docs/`: the pages are in `docs/src/`, the configuration in
`docs/make.jl`. To build it:

```bash
julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
julia --project=docs docs/make.jl
```

and open `docs/build/index.html`. The build fails on a doctest that does not
match, a link that does not resolve, and an exported name without a
docstring (`checkdocs = :exports`), and CI runs the same build on every pull
request. So:

- Document every exported name with a docstring; the API reference is
  generated from the docstrings, and the manual pages link to them with
  `` [`name`](@ref) ``.
- Use a `jldoctest` for an example whose output is deterministic (integers,
  strings). Use `@example` where the output depends on the random stream,
  which Julia does not promise to keep between versions, so a new Julia does
  not fail the build for a harmless change.
- Keep the pages and the docstrings in step with the code in the same change.
  The README stays short; put new explanation in `docs/src/`.

CI deploys the site to the `gh-pages` branch: the development version on a
push to `master`, a versioned copy on a tag, and a preview for each pull
request from this repository (the link is posted on the pull request).
Deployment signs in with the `DOCUMENTER_KEY` repository secret.

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

## Use of AI

This package is developed with an AI coding agent, and contributors may use
one too. This section says how, so that readers, reviewers and journals can
judge the work, and what is expected of anyone who contributes with AI.

### How this package was developed

- The first implementation, a script, was written by the maintainer by hand,
  before coding agents were available: the first 12 commits, from
  2020-10-13 to 2021-09-15.
- Since 2026-10-20 (commit `f1d9d51`, "Create the project structure") the
  work has been done with Claude Code, using Claude Sonnet 5.5
  (`claude-sonnet-5-5`). The agent turned the script into a Julia package and
  added what came after: the `init`/`solve`/`step!` interface, monitors,
  `trials_for`, table input, tests, benchmarks and documentation. The
  maintainer set the direction, reviewed the work on GitHub, and corrected
  it where it departed from the design or style they wanted.
- Every change since then has an issue, a branch and a pull request, so the
  requests, reviews and corrections can be read in order. In practice the
  agent drafts the issues, pull requests and commit messages, and the
  maintainer reads them on GitHub and asks for changes; the maintainer
  merges every pull request.
- Every commit an agent wrote has a `Co-Authored-By:` trailer naming the
  model, so the model behind any commit is in the history:

  ```bash
  git log --format='%h %(trailers:key=Co-Authored-By,valueonly)'
  ```

  The 12 commits before 2026-10-20 have none because they are human.
- Review is not the only evidence of correctness. The library is tested
  against the exact p-values (every within-block arrangement enumerated) and
  against Sakai's own implementation (see `test/reference/README.md`), and CI
  runs the tests on two Julia versions, at the lowest dependency versions,
  and builds the documentation.

### What is expected of contributors

These are requirements, and they apply to people and agents alike.

- **Say that AI helped**, in the pull request description. Keep the
  `Co-Authored-By:` trailer on commits an agent wrote.
- **You are accountable for what you post** (issues, comments, commits,
  pull requests, code), whoever or whatever wrote it. Maintainers may close
  contributions with unverified claims, text that does not match the code, or
  changes nobody asked for.
- **Do not run an agent unattended.** An agent works in a session that a
  person is running and answers for.
- **Hold AI-written tests and documentation to the standard of code:** the
  tests must test something, and the documentation must be true of the code.
- **Say what you verified** in the pull request, and what you did not.
- The rules in "Making a change" apply, including an issue for every change.
