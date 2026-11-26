# What counts as a block

Each trial shuffles the responses of every block independently of every
other block. So the test treats the blocks as independent units, each
sampled, or randomized, on its own. When several rows of your data come from
one such unit, aggregate them to one response for the unit before you build
the problem. Otherwise the shuffle splits values that belong together, the
shuffled ranges vary less than they should, and the p-values are too small.

Two cases are common: one treatment measured several times in one block, and
blocks that were sampled together. They call for different aggregations.

## Repeated responses

Here each treatment has several responses in one block: a language model
answering one question K times, a lab measuring one sample in replicate, a
rater scoring one item twice. The tidy table then has K rows for the block
and treatment, and the library rejects it with an error that names the pair.

Make the response the **mean** of the K values. The test takes fractional
responses unchanged, for example the fraction of K answers that were
correct. The mean, and not the sum, is the right summary when K differs
between blocks or treatments, because a sum would favor whichever
treatment was measured more often.

```julia
using DataFrames, Statistics

df = combine(
    groupby(df, [:block, :treatment]),
    :response => mean => :response,
)
```

Giving each repeat its own block id (`q1#1`, `q1#2`, ...) gets past the error,
but it is wrong. It makes K correlated values K blocks, which the shuffle sends
to different treatments independently. Miller
([2024](https://arxiv.org/abs/2411.00640), Section 3.1) makes the same point
for standard errors.

The repeats must be independent draws under the same conditions: for a
language model, a fresh conversation for every answer, with the same settings.
Repeats that share state, such as answers within one conversation, vary less
than independent ones, and their mean is less precise than it looks.

The library rejects the duplicate rows instead of averaging them for you,
because the mean is one choice among several (the median, a majority vote,
the best of K), and which one answers your question is your decision, as with
[Missing responses](@ref).

## Blocks sampled together

Here blocks come in groups that were sampled as a unit, and the responses of
a treatment are correlated within a group: several questions about one
passage, one problem translated into several languages, patients of one
clinic, plots in one field. A model that misreads a passage tends to miss all
of its questions; a clinic that runs a treatment poorly does so for all of its
patients. Call such a group a *cluster*.

Make the cluster the block. Its response for a treatment is the **sum** of
that treatment's responses over the cluster's blocks, divided by the average
number of blocks in a cluster:

```julia
using DataFrames

average = length(unique(df.block)) / length(unique(df.cluster))
df = combine(
    groupby(df, [:cluster, :treatment]),
    :response => (r -> sum(r) / average) => :response,
)
problem = RandomizedTukeyProblem(
    df;
    block=:cluster,
    treatment=:treatment,
    response=:response,
)
```

This is exactly the test that gives every block of a cluster the same
arrangement of treatments, with clusters arranged independently. With `n`
blocks in `C` clusters, and `S_c[t]` the sum of treatment `t`'s responses over
cluster `c`, a trial that gives cluster `c` the arrangement `p_c` makes
treatment `t`'s mean

```
(1/n) * sum over c of S_c[p_c(t)]
```

which is the mean the test computes from one row per cluster holding
`S_c / (n/C)`. So the p-values are those of the clustered shuffle, and the
means and differences in the results are those of the original blocks.
Dividing by `n/C` changes nothing else: it scales the observed differences
and every shuffled range alike.

With clusters of equal size, this response is the mean of the cluster's
blocks. With unequal sizes, the plain mean of each cluster is a different
comparison: it weights every cluster equally, where the sum weights every
block equally. Either can be the question you want answered, but only the
sum reproduces the clustered shuffle.

The aggregation needs every block in one cluster and, as always, a response
for every treatment in every block.

### Few clusters, coarse p-values

After aggregating there are only `C` blocks, and with `m` treatments no
exact p-value can be below `(m!)^(1 - C)`. Relabeling the treatments in the
same way in every cluster leaves the range unchanged, so at least `m!` of the
`(m!)^C` arrangements reach the observed range. With 3 treatments in 4
clusters that floor is `1/216`; with 3 treatments in 2 clusters it is `1/6`.
This is the price of the dependence in the data. More trials do not lower it,
only more clusters do.

### Clusters and strata

Whether to aggregate follows from how the blocks were sampled, not from
correlation alone (Abadie et al.,
[2023](https://doi.org/10.1093/qje/qjac038)). Aggregate when the blocks were
drawn in clusters from a larger population you mean to generalize to.
Groups fixed by the design, such as the subjects of a benchmark chosen to
cover a list, are *strata*. Every stratum is present by design, and its
blocks can stay as they are.
