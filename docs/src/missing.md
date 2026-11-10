# Missing responses

A missing or `NaN` response makes the test meaningless, so the library rejects
`NaN` with an error that says how many there are. Each trial shuffles the
`NaN` into some treatment, so every trial's range is `NaN` and every p-value
is meaningless, including those of pairs that do not involve the treatment it
came from.

What to do is your decision, and it depends on why the responses are missing.
The sound option is to keep only the blocks that have a response for every
treatment (complete cases). The test is then exactly valid on those blocks,
because every treatment is still averaged over the same blocks. That is right
for a block that is undefined for all treatments (for example, a dataset where
the metric is undefined for every model, or, in information retrieval, a topic
with no relevant documents), but it flatters a treatment whose failures are
dropped. Averaging each treatment over only its own blocks (`nanmean`) is not
offered: it compares treatments on different blocks, which defeats the point of
the test.

With a DataFrame, complete cases are a line or two:

```julia
# wide: one row per block
df = dropmissing(df)                                   # empty cells
df = filter(row -> all(!isnan, row[Not(:block)]), df)  # NaN; :block is the id

# tidy: one row per block and treatment; also drops blocks with a missing row
ntreatments = length(unique(df.treatment))
usable(x) = !ismissing(x) && !isnan(x)
df = DataFrame(filter(groupby(df, :block)) do rows
    nrow(rows) == ntreatments && all(usable, rows.response)
end)
```
