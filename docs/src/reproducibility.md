# Threads and reproducibility

Start Julia with more threads to use them (`-t N`, or `-t auto`):

```bash
julia -t auto --project=examples examples/run.jl data.csv 100000
```

Every trial has its own random stream, which depends only on a base seed and
on the number of the trial. The base seed is drawn from the random number
generator you pass as the `rng` keyword (the global one if left out) when the
run is made. So with a fixed `rng` state the p-values are the same at any
thread count, and however the trials are cut into chunks for the threads:

```julia
using Random
problem = RandomizedTukeyProblem(responses)
solve(problem, FixedTrials(100_000); rng=Xoshiro(1))
```

Seeding the global generator (`Random.seed!(1)`) and leaving `rng` out does
the same. The example script takes a seed as its third argument.

What this does and does not promise:

- The same seed, `trials`, responses and Julia version give the same p-values
  on any machine and thread count. The arrangement a trial makes of its
  stream is the package's own shuffle, which is the same in every Julia
  version. The stream itself is Julia's (`Xoshiro` and its seeding), which
  is not guaranteed to stay the same across Julia versions.
- The chunk size (64 trials per task) only schedules the work and is not part
  of the result. The number of random numbers a trial draws and the way a
  trial's stream is derived from the seed are, so they may change between
  package versions. Record the package version with the seed. They have
  changed once since the first release: 0.1.0 shuffled with Julia's
  `shuffle!`, so p-values recorded with 0.1.0 are reproduced with 0.1.0 and
  not with later versions, whose p-values differ from them by Monte Carlo
  error.
- It is a safeguard for an exact re-run, not for the conclusions. A p-value
  has a Monte Carlo error of about `sqrt(p(1 - p) / trials)` (0.0007 for
  p = 0.05 and `trials` = 100 000; see [How precise is a p-value?](@ref)), so
  choose `trials` large enough that the decisions do not depend on the seed,
  and record the seed, `trials` and versions with the results.
