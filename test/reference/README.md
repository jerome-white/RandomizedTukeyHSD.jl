# Reference data

`test/reference.jl` checks the library against two references that do not
share its code, on problems small enough to enumerate.

## Exact p-values

`exact_pvalues` in `test/helpers.jl` enumerates every within-block
arrangement of the responses (n!^blocks of them: 1296 for 3 treatments × 4
blocks) and counts those whose range of treatment means is at least each
pair's observed absolute difference. There is no Monte Carlo error, so the
library has to match it to within its own standard error.

## Sakai's implementation

The randomised Tukey HSD test in Tetsuya Sakai's own tools is **Discpower**
(C plus shell and awk), listed on <https://sakailab.com/download/> and
distributed from the NTCIR tools page as
<http://research.nii.ac.jp/ntcir/tools/Discpower160507.tar.gz>.

`sakai_reference.sh` downloads it (checking the SHA-256 recorded in the
script), builds it in a temporary directory, and writes
`treatment1,treatment2,difference,p` for a tidy CSV (Sakai's tool calls
blocks topics and treatments systems; the names here follow the library):

```bash
cd test/reference
sh sakai_reference.sh ../data/ties.csv > ../data/ties_sakai.csv
sh sakai_reference.sh ../data/distinct.csv > ../data/distinct_sakai.csv
sh sakai_reference.sh ../data/tiny.csv > ../data/tiny_sakai.csv
```

It needs `curl`, `make`, a C compiler, `awk` and Julia, and takes a few
seconds per fixture. The committed files were produced on 2026-10-21.

How it uses Sakai's code:

- His C program `permmat2maxmin` is fed **every** within-block arrangement
  (written by `arrangements.jl`) instead of random permutations, so the
  p-values are exact and need no Monte Carlo tolerance.
- The p-value is computed with the rule from his `Random-test` script
  (`$4 >= diff { count++ }`, with the treatment means printed by awk), copied
  into the shell script.
- **His shuffling is not exercised.** It sorts awk `rand()` keys, which is
  unseeded and slow (one process per matrix cell; he recommends 1000 to
  5000 trials, his `B`).

One change was needed to build it: the 2011 K&R `main()` is rejected by
current compilers, so the Makefile is edited to build with `-std=gnu89`.
Discpower carries no licence, so its source is fetched on demand and not
redistributed here; only its output is committed.

Its README states that a range equal to the observed difference counts
("ordinary"), but the code does not always achieve it: on other data its
floating-point comparison can miss those trials. See issue #17.

## The fixtures

Responses in `ties.csv` and `distinct.csv` are multiples of 0.25 and 0.0625
with 4 blocks, so sums and means are exactly representable and print exactly in
six decimals. That keeps floating-point rounding out of both references, so
they test the method and not the arithmetic.

- `ties.csv`: 4 blocks × 3 treatments with tied responses.
- `distinct.csv`: 4 blocks × 3 treatments, no ties within a block.
- `tiny.csv`: multiples of 0.05, so some permuted ranges equal an observed
  difference mathematically but not in floating point. It documents the
  known limitation in issue #17: Sakai's code gives the mathematical value
  0.4028 for the A–B pair, the library (plain `>=`) converges to 0.3935,
  and the tests check both facts.

## Tolerance

The library is compared with 5 standard errors, `sqrt(p (1 - p) / trials)`,
plus `1 / trials` so that p-values of exactly 0 or 1 still get a tolerance.
With about 12 such comparisons the chance of a spurious failure is roughly
1 in 100 000 per run for a random seed. The tests seed the generator, and
since #25 the p-values for a seed are the same at any thread count, so a
failure is reproducible and not a flake. The exact enumeration and
Sakai's code are deterministic and are compared to 1e-5, the six significant
digits his code prints.
