# Reference data

`test/reference.jl` checks the library against two independent references on
problems small enough to enumerate. This directory holds what is needed to
regenerate the second one.

## Exact p-values

`exact_pvalues` in `test/helpers.jl` enumerates every within-topic
arrangement of the scores (n!^topics of them: 1296 for 3 systems × 4 topics)
and counts those whose range of system means is at least each pair's observed
absolute difference. There is no Monte Carlo error, so the library has to
match it to within its own standard error.

## Python reference

`../data/generic_python.csv` and `../data/ties_python.csv` are the output of
the Python `RandomisedTukey` implementation in the original sakai-book
repository, run on `../data/generic.csv` and `../data/ties.csv`:

```bash
cd test/reference
PYTHONPATH=/path/to/sakai-book python3 python_reference.py \
    ../data/generic.csv 1000000 8 > ../data/generic_python.csv
PYTHONPATH=/path/to/sakai-book python3 python_reference.py \
    ../data/ties.csv 1000000 8 > ../data/ties_python.csv
```

Each takes a minute or two on 8 cores. The committed files were produced on
2026-10-21 with sakai-book at `ce9f63d`, Python 3.13.2, numpy 2.2.5 and
scipy 1.15.3, with B = 1 000 000.

`python_reference.py` exists because `chapters/04/rthsd.py` cannot be used
for this on macOS: it has no `if __name__ == '__main__'` guard, so with the
`spawn` start method every worker re-runs the script, which then waits on
stdin and never finishes.

## The fixtures

- `generic.csv`: 4 topics × 3 systems with irregular decimals.
- `ties.csv`: 4 topics × 3 systems with tied scores, all multiples of 0.25
  (exactly representable, with an exactly representable mean over 4 topics).
- `tiny.csv`: multiples of 0.05. Not used as a passing reference, because
  its scores trigger the floating-point behaviour in issue #17; it is used
  for the `@test_broken` that documents it.

`generic.csv` and `ties.csv` give the same exact p-values with or without a
floating-point tolerance, so they test the algorithm and not the rounding.

## Tolerance

Comparisons allow 5 standard errors, `sqrt(p (1 - p) / B)`, plus `1 / B` so
that p-values of exactly 0 or 1 still get a tolerance. With about 18 such
comparisons the chance of a spurious failure is roughly 1 in 100 000 per run.
`Random.seed!` does not make multi-threaded runs reproducible, so a failure
should be re-run before it is believed.
