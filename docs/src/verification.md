# How it is checked

`] test` runs the suite, and CI runs it on Julia 1.10 and the latest release at
one and four threads. A further CI job runs it on Julia 1.10 with every
dependency at the lowest version its `[compat]` bound allows, so the lower
bounds are tested, not assumed. The suite starts with
[Aqua.jl](https://github.com/JuliaTesting/Aqua.jl), the community's
package-quality checks. See
[CONTRIBUTING.md](https://github.com/jerome-white/RandomizedTukeyHSD.jl/blob/master/CONTRIBUTING.md)
for the conventions.

Besides unit tests, the library is compared with the exact p-values (every
within-block arrangement enumerated) and with the output of Sakai's own
implementation, Discpower, on problems small enough to enumerate. See
[`test/reference/README.md`](https://github.com/jerome-white/RandomizedTukeyHSD.jl/blob/master/test/reference/README.md).

The [`benchmark/`](https://github.com/jerome-white/RandomizedTukeyHSD.jl/tree/master/benchmark)
directory holds the benchmark suite, the baseline measured before the
performance work, and the tables for each change.
