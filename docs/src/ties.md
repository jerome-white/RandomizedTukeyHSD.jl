# Known limitation: floating-point ties

A trial counts when its range is `>=` the observed difference. When a permuted
range equals the observed difference mathematically but differs from it in the
last bit, which can happen with responses on a regular grid such as multiples
of 0.05, that trial is not counted. P-values can then be slightly too small.
There is deliberately no tolerance in the library. In the 4-block example in
`test/data/tiny.csv` the pair (A, B) converges to 0.3935 where the
mathematical value is 0.4028, which Sakai's Discpower gives because it rounds
ranges to six decimals. Responses with many distinct values (most real
metrics) are far less likely to be affected. The effect is recorded in
`test/reference.jl` (issue #17).

The comparison does not depend on how Julia is started or compiled. The
observed means and the means of every trial are added in the same fixed order,
one block after the other, so a trial that only relabels the treatments the
same way in every block has bit-for-bit the observed means and is always
counted. (`sum` and `mean` with `dims` may add in another order, for example
with and without `--check-bounds=yes`, which changed the last bit and the
p-value on tied data before issue #74.)
