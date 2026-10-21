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

Like `bin/`, the environment needs Julia 1.11 or newer (`[sources]`). The
script prints a Markdown table of the median and minimum time over 10
samples, microseconds per trial, memory and allocation count for each
combination of 5/10/20 systems, 50/100 topics and B = 1000/10000, on seeded
random scores. It prints the Julia version, CPU, thread configuration and
load average first, so a result can be tied to its environment.

## Baseline

Code: `92dd849` (the library as first extracted in #2). Julia 1.13.2 on an
Apple M4 (10 cores), macOS. The machine was not idle: the load average was
2.9 to 3.8 from other processes during the runs. Repeating the single-thread
run gave per-trial times within 2.5% of the first run for every row.

`us/trial` is the median time divided by B.

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

## Caveats

- One machine, one Julia version, uniform random scores.
- The `-t 1` run has no interactive thread; the others have one (Julia's
  default).
- Small configurations (B = 1000) include thread start-up in the timing.
- Wall-clock only; no profile was taken.
