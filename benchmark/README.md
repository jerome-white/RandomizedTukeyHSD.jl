# Benchmarks

`randomized_tukey_hsd` timed over a grid of problem sizes. This directory
holds the suite and the **baseline** measured before the performance work
(#3-#6), so later changes can be compared against numbers rather than
impressions.

## Running

```bash
julia --project=benchmark -e 'using Pkg; Pkg.instantiate()'
julia --project=benchmark -t 1 benchmark/randomized_tukey.jl
julia --project=benchmark -t 4 benchmark/randomized_tukey.jl
```

The environment needs Julia 1.11 or newer (`[sources]`). The
script prints a Markdown table of the median and minimum time over 10
samples, microseconds per trial, memory and allocation count for each
combination of 5/10/20/50/100 systems, 50/100 topics and B = 1000/10000, on
seeded random scores. It prints the Julia version, CPU, thread configuration and
load average first, so a result can be tied to its environment.

## Baseline

Code: `92dd849` (the library as first extracted in #2). Julia 1.13.2 on an
Apple M4 (10 cores), macOS. The machine was not idle: the load average was
2.9 to 3.8 from other processes during the runs. Repeating the single-thread
run gave per-trial times within 2.5% of the first run for every row.

`us/trial` is the median time divided by B.

`B` in the tables below is the `trials` argument, which was called `B` when they
were recorded (renamed in #39); new runs print `trials` as the column header.

### 1 thread (`-t 1`)

| systems | topics | B | median (ms) | us/trial | min (ms) | MiB | allocs |
|--:|--:|--:|--:|--:|--:|--:|--:|
| systems | topics | B | median (ms) | us/trial | min (ms) | MiB | allocs |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 5 | 50 | 1000 | 1.3 | 1.32 | 1.3 | 3.0 | 25049 |
| 5 | 50 | 10000 | 13.6 | 1.36 | 13.2 | 29.8 | 250049 |
| 5 | 100 | 1000 | 2.4 | 2.43 | 2.3 | 5.0 | 26050 |
| 5 | 100 | 10000 | 23.2 | 2.32 | 23.0 | 49.8 | 260050 |
| 10 | 50 | 1000 | 2.5 | 2.50 | 2.3 | 5.1 | 26122 |
| 10 | 50 | 10000 | 24.3 | 2.43 | 23.2 | 50.7 | 260122 |
| 10 | 100 | 1000 | 4.5 | 4.46 | 4.1 | 9.0 | 26122 |
| 10 | 100 | 10000 | 41.5 | 4.15 | 41.3 | 89.7 | 260122 |
| 20 | 50 | 1000 | 4.7 | 4.66 | 4.4 | 9.2 | 26415 |
| 20 | 50 | 10000 | 43.3 | 4.33 | 43.1 | 91.3 | 260415 |
| 20 | 100 | 1000 | 8.4 | 8.42 | 8.2 | 17.0 | 26415 |
| 20 | 100 | 10000 | 77.8 | 7.78 | 77.6 | 169.4 | 260415 |

### 4 threads (`-t 4`)

| systems | topics | B | median (ms) | us/trial | min (ms) | MiB | allocs |
|--:|--:|--:|--:|--:|--:|--:|--:|
| systems | topics | B | median (ms) | us/trial | min (ms) | MiB | allocs |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 5 | 50 | 1000 | 0.4 | 0.40 | 0.4 | 3.0 | 25065 |
| 5 | 50 | 10000 | 4.2 | 0.42 | 3.7 | 29.8 | 250065 |
| 5 | 100 | 1000 | 0.7 | 0.71 | 0.7 | 5.0 | 26065 |
| 5 | 100 | 10000 | 7.6 | 0.76 | 7.1 | 49.8 | 260065 |
| 10 | 50 | 1000 | 0.7 | 0.74 | 0.7 | 5.1 | 26138 |
| 10 | 50 | 10000 | 7.3 | 0.73 | 6.7 | 50.7 | 260138 |
| 10 | 100 | 1000 | 1.2 | 1.21 | 1.1 | 9.1 | 26138 |
| 10 | 100 | 10000 | 11.9 | 1.19 | 11.5 | 89.8 | 260138 |
| 20 | 50 | 1000 | 1.3 | 1.25 | 1.2 | 9.3 | 26430 |
| 20 | 50 | 10000 | 12.0 | 1.20 | 11.8 | 91.4 | 260430 |
| 20 | 100 | 1000 | 2.2 | 2.23 | 2.1 | 17.1 | 26430 |
| 20 | 100 | 10000 | 21.3 | 2.13 | 21.1 | 169.6 | 260430 |

### 10 threads (`-t 10`)

| systems | topics | B | median (ms) | us/trial | min (ms) | MiB | allocs |
|--:|--:|--:|--:|--:|--:|--:|--:|
| systems | topics | B | median (ms) | us/trial | min (ms) | MiB | allocs |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 5 | 50 | 1000 | 0.4 | 0.44 | 0.4 | 3.0 | 25096 |
| 5 | 50 | 10000 | 3.6 | 0.36 | 2.9 | 29.8 | 250096 |
| 5 | 100 | 1000 | 0.6 | 0.61 | 0.6 | 5.1 | 26096 |
| 5 | 100 | 10000 | 5.7 | 0.57 | 5.3 | 49.8 | 260096 |
| 10 | 50 | 1000 | 0.6 | 0.60 | 0.5 | 5.2 | 26168 |
| 10 | 50 | 10000 | 4.9 | 0.49 | 4.7 | 50.8 | 260168 |
| 10 | 100 | 1000 | 0.9 | 0.89 | 0.8 | 9.2 | 26168 |
| 10 | 100 | 10000 | 8.1 | 0.81 | 7.6 | 89.9 | 260168 |
| 20 | 50 | 1000 | 0.9 | 0.92 | 0.9 | 9.4 | 26460 |
| 20 | 50 | 10000 | 8.6 | 0.86 | 8.2 | 91.5 | 260460 |
| 20 | 100 | 1000 | 1.4 | 1.44 | 1.4 | 17.4 | 26460 |
| 20 | 100 | 10000 | 14.4 | 1.44 | 13.6 | 169.8 | 260460 |

## What the baseline shows

These are readings of the tables above, not profiles.

- **Cost tracks the number of scores.** Single-threaded time per trial is
  roughly 4 to 5 ns per score (systems × topics): 1.3 us for 250 scores, 7.8
  us for 2000.
- **The pair loop is a small part at these sizes.** Rows with the same number
  of scores but different pair counts differ by little: 10 × 100 (45 pairs)
  takes 4.15 us/trial and 20 × 50 (190 pairs) takes 4.33 us, and 5 × 100
  (10 pairs) takes 2.32 us against 10 × 50 (45 pairs) at 2.43 us. That is
  about 1 to 3 ns per extra pair. It will matter more with many systems,
  since the pair count grows quadratically, but #4 should not be expected to
  help much at 20 systems or fewer.
- **Memory is about one copy of the data per trial.** For 20 × 100 the run
  allocates 169 MiB for 10 000 trials, about 18 KB per trial against 16 KB of
  scores, and about 26 allocations per trial regardless of size. That points
  at `mapslices` and `mean(...; dims=2)` (#5) as the first thing to look at.
- **Threads scale reasonably.** At 20 × 100, B = 10 000, time per trial goes
  from 7.8 us (1 thread) to 2.1 us (4 threads, 3.7×) and 1.4 us (10 threads,
  5.4×). The M4 mixes performance and efficiency cores, so less than linear
  scaling beyond four threads is expected. The smallest case (5 × 50) gains
  little from 4 to 10 threads (0.42 to 0.36 us/trial at B = 10 000, and no
  gain at B = 1000).
- **Allocation volume does not change with threads**, so the multi-threaded
  runs spend the same memory traffic in less wall-clock time.

## After #5: no per-trial allocation

The shuffle is done in place and the system means go into a preallocated
buffer, so a trial no longer allocates. Each table compares the library
before the change with after it, measured back to back on the same machine
so that both saw the same load (about 1.7 to 2.4, lighter than during the
baseline above, which is why "before" differs a little from the baseline
tables).

Allocation per call falls from about 250 000 allocations and 30 to 170 MiB
at B = 10 000 to a few hundred allocations and under half a MiB, which do not
grow with B (for example 5 systems × 50 topics: 250049 allocations, 29.8 MiB
before and 51, 0.0 MiB after at B = 10 000; 20 × 100: 260415 allocations,
169.4 MiB before and 417, 0.1 MiB after).

### 1 thread (`-t 1`)

| systems | topics | B | before (us/trial) | after (us/trial) | speedup |
|--:|--:|--:|--:|--:|--:|
| 5 | 50 | 1000 | 1.31 | 0.62 | 2.11x |
| 5 | 50 | 10000 | 1.36 | 0.61 | 2.23x |
| 5 | 100 | 1000 | 2.42 | 1.18 | 2.05x |
| 5 | 100 | 10000 | 2.32 | 1.17 | 1.98x |
| 10 | 50 | 1000 | 2.51 | 1.38 | 1.82x |
| 10 | 50 | 10000 | 2.48 | 1.36 | 1.82x |
| 10 | 100 | 1000 | 4.48 | 2.62 | 1.71x |
| 10 | 100 | 10000 | 4.22 | 2.61 | 1.62x |
| 20 | 50 | 1000 | 4.66 | 2.92 | 1.60x |
| 20 | 50 | 10000 | 4.34 | 2.90 | 1.50x |
| 20 | 100 | 1000 | 8.34 | 5.39 | 1.55x |
| 20 | 100 | 10000 | 7.77 | 5.38 | 1.44x |

### 4 threads (`-t 4`)

| systems | topics | B | before (us/trial) | after (us/trial) | speedup |
|--:|--:|--:|--:|--:|--:|
| 5 | 50 | 1000 | 0.44 | 0.24 | 1.83x |
| 5 | 50 | 10000 | 0.43 | 0.21 | 2.05x |
| 5 | 100 | 1000 | 0.76 | 0.42 | 1.81x |
| 5 | 100 | 10000 | 0.77 | 0.40 | 1.93x |
| 10 | 50 | 1000 | 0.66 | 0.39 | 1.69x |
| 10 | 50 | 10000 | 0.67 | 0.36 | 1.86x |
| 10 | 100 | 1000 | 1.18 | 0.71 | 1.66x |
| 10 | 100 | 10000 | 1.15 | 0.69 | 1.67x |
| 20 | 50 | 1000 | 1.21 | 0.80 | 1.51x |
| 20 | 50 | 10000 | 1.19 | 0.76 | 1.57x |
| 20 | 100 | 1000 | 2.26 | 1.43 | 1.58x |
| 20 | 100 | 10000 | 2.12 | 1.41 | 1.50x |

### 10 threads (`-t 10`)

Median of three interleaved runs, because single 10-thread runs of the same
code differed by up to 70% on one row.

| systems | topics | B | before (us/trial) | after (us/trial) | speedup |
|--:|--:|--:|--:|--:|--:|
| 5 | 50 | 1000 | 0.43 | 0.21 | 2.05x |
| 5 | 50 | 10000 | 0.36 | 0.15 | 2.40x |
| 5 | 100 | 1000 | 0.64 | 0.38 | 1.68x |
| 5 | 100 | 10000 | 0.56 | 0.27 | 2.07x |
| 10 | 50 | 1000 | 0.54 | 0.33 | 1.64x |
| 10 | 50 | 10000 | 0.50 | 0.23 | 2.17x |
| 10 | 100 | 1000 | 0.85 | 0.54 | 1.57x |
| 10 | 100 | 10000 | 0.81 | 0.42 | 1.93x |
| 20 | 50 | 1000 | 0.87 | 0.61 | 1.43x |
| 20 | 50 | 10000 | 0.86 | 0.49 | 1.76x |
| 20 | 100 | 1000 | 1.47 | 0.97 | 1.52x |
| 20 | 100 | 10000 | 1.42 | 0.85 | 1.67x |

The speedup is smaller for large problems, presumably because the shuffle and
the sums are now most of the time (not profiled). These numbers come from one
machine; the per-row noise at 4 and 10 threads is larger than at one thread.

## Checking that a change keeps the results

`snapshot.jl` prints p-values for the fixtures and two random matrices under
a fixed seed. The output is deterministic (and, since #24, the same at any
thread count), so a change that should only affect speed can be checked for
**bit-identical** results:

```bash
julia --project=benchmark -t 1 benchmark/snapshot.jl > before.txt
# ... make the change ...
julia --project=benchmark -t 1 benchmark/snapshot.jl > after.txt
diff before.txt after.txt && echo identical
```

This is stricter than the tests, which allow for Monte Carlo error. It only
works while the sequence of random draws is unchanged; a change to how the
shuffling or the number of draws works will legitimately alter the output.

## After #4: sorted p-value lookup

Each trial stores its range, the ranges are sorted once, and each pair's
p-value is found by binary search, instead of comparing every trial with
every pair. The grid now includes 50 and 100 systems, where the number of
pairs (1225 and 4950) makes the old pair loop expensive. "Before" is the code
after #5; before and after were measured back to back (medians of two runs at
1 and 4 threads and three at 10 threads) so both saw the same load.

The gain depends on the number of pairs. At 20 systems or fewer it is at most
16% and often within noise; at 100 systems × 50 topics it is about 2×: a trial
falls from 24.6 to 12.6 us, so the pair loop was about half of the old trial
there. At 4 and 10 threads the small rows are within noise of 1.0×:
individual rows moved by up to 38% (4 threads) and 26% (10 threads) between
runs of the same code.

The cost is memory. The ranges are kept, so memory now grows with B: about 16
bytes per trial (the vector and the sort's scratch copy), for example 15 MiB
at B = 1 000 000 and 76 MiB at B = 5 000 000, where the old code allocated
almost nothing. The sort itself does not show up: at 50 topics × 5 systems a
trial costs 0.59 us at B = 5 000 000 against 0.61 us before. Allocations per
call at 100 × 100 and B = 10 000 fall from 9938 to 37.

### 1 thread (`-t 1`)

| systems | topics | B | before (us/trial) | after (us/trial) | speedup |
|--:|--:|--:|--:|--:|--:|
| 5 | 50 | 1000 | 0.62 | 0.60 | 1.04x |
| 5 | 50 | 10000 | 0.61 | 0.58 | 1.05x |
| 5 | 100 | 1000 | 1.18 | 1.17 | 1.01x |
| 5 | 100 | 10000 | 1.17 | 1.15 | 1.02x |
| 10 | 50 | 1000 | 1.38 | 1.29 | 1.07x |
| 10 | 50 | 10000 | 1.37 | 1.27 | 1.07x |
| 10 | 100 | 1000 | 2.62 | 2.54 | 1.03x |
| 10 | 100 | 10000 | 2.62 | 2.52 | 1.04x |
| 20 | 50 | 1000 | 2.92 | 2.52 | 1.16x |
| 20 | 50 | 10000 | 2.90 | 2.50 | 1.16x |
| 20 | 100 | 1000 | 5.39 | 5.00 | 1.08x |
| 20 | 100 | 10000 | 5.38 | 4.99 | 1.08x |
| 50 | 50 | 1000 | 9.07 | 6.33 | 1.43x |
| 50 | 50 | 10000 | 9.04 | 6.29 | 1.44x |
| 50 | 100 | 1000 | 15.37 | 12.58 | 1.22x |
| 50 | 100 | 10000 | 15.32 | 12.55 | 1.22x |
| 100 | 50 | 1000 | 24.82 | 12.66 | 1.96x |
| 100 | 50 | 10000 | 24.58 | 12.55 | 1.96x |
| 100 | 100 | 1000 | 37.32 | 25.09 | 1.49x |
| 100 | 100 | 10000 | 37.17 | 25.00 | 1.49x |

### 4 threads (`-t 4`)

| systems | topics | B | before (us/trial) | after (us/trial) | speedup |
|--:|--:|--:|--:|--:|--:|
| 5 | 50 | 1000 | 0.23 | 0.29 | 0.81x |
| 5 | 50 | 10000 | 0.21 | 0.21 | 1.00x |
| 5 | 100 | 1000 | 0.41 | 0.42 | 0.98x |
| 5 | 100 | 10000 | 0.40 | 0.40 | 1.00x |
| 10 | 50 | 1000 | 0.40 | 0.38 | 1.05x |
| 10 | 50 | 10000 | 0.36 | 0.34 | 1.06x |
| 10 | 100 | 1000 | 0.71 | 0.71 | 1.01x |
| 10 | 100 | 10000 | 0.69 | 0.66 | 1.04x |
| 20 | 50 | 1000 | 0.80 | 0.71 | 1.12x |
| 20 | 50 | 10000 | 0.76 | 0.67 | 1.14x |
| 20 | 100 | 1000 | 1.45 | 1.35 | 1.07x |
| 20 | 100 | 10000 | 1.40 | 1.32 | 1.06x |
| 50 | 50 | 1000 | 2.41 | 1.72 | 1.40x |
| 50 | 50 | 10000 | 2.41 | 1.66 | 1.45x |
| 50 | 100 | 1000 | 4.03 | 3.33 | 1.21x |
| 50 | 100 | 10000 | 4.06 | 3.33 | 1.22x |
| 100 | 50 | 1000 | 6.99 | 3.40 | 2.06x |
| 100 | 50 | 10000 | 7.00 | 3.34 | 2.10x |
| 100 | 100 | 1000 | 10.46 | 6.66 | 1.57x |
| 100 | 100 | 10000 | 10.45 | 6.67 | 1.57x |

### 10 threads (`-t 10`)

| systems | topics | B | before (us/trial) | after (us/trial) | speedup |
|--:|--:|--:|--:|--:|--:|
| 5 | 50 | 1000 | 0.21 | 0.22 | 0.95x |
| 5 | 50 | 10000 | 0.15 | 0.15 | 1.00x |
| 5 | 100 | 1000 | 0.37 | 0.37 | 1.00x |
| 5 | 100 | 10000 | 0.27 | 0.27 | 1.00x |
| 10 | 50 | 1000 | 0.33 | 0.31 | 1.06x |
| 10 | 50 | 10000 | 0.23 | 0.21 | 1.10x |
| 10 | 100 | 1000 | 0.54 | 0.51 | 1.06x |
| 10 | 100 | 10000 | 0.42 | 0.39 | 1.08x |
| 20 | 50 | 1000 | 0.60 | 0.51 | 1.18x |
| 20 | 50 | 10000 | 0.49 | 0.39 | 1.26x |
| 20 | 100 | 1000 | 0.96 | 0.88 | 1.09x |
| 20 | 100 | 10000 | 0.85 | 0.75 | 1.13x |
| 50 | 50 | 1000 | 1.82 | 1.09 | 1.67x |
| 50 | 50 | 10000 | 1.66 | 0.94 | 1.77x |
| 50 | 100 | 1000 | 2.77 | 2.00 | 1.39x |
| 50 | 100 | 10000 | 2.59 | 1.89 | 1.37x |
| 100 | 50 | 1000 | 5.27 | 2.09 | 2.52x |
| 100 | 50 | 10000 | 4.89 | 1.94 | 2.52x |
| 100 | 100 | 1000 | 7.54 | 4.01 | 1.88x |
| 100 | 100 | 10000 | 6.53 | 3.84 | 1.70x |

## Caveats

- One machine, one Julia version, uniform random scores.
- The `-t 1` run has no interactive thread; the others have one (Julia's
  default).
- Small configurations (B = 1000) include thread start-up in the timing.
- Wall-clock only; no profile was taken.
