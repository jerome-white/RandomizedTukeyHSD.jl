"""
    randomized_tukey_hsd([rng,] table; trials, block, treatment, value)

The same test on a [Tables.jl](https://tables.juliadata.org) table, such as
a `DataFrame`, so that the names of the treatments come with the data. The
shape is told by which of `block`, `treatment` and `value` are given; each
is the name of a column, as a `Symbol` or a `String`.

- **Wide**, with none given: each column is a treatment and each row a
  block. The result names the treatments by the column names, as `Symbol`s,
  as the table gives them.
  Pass only `block` to leave out a column that identifies the rows.
- **Tidy**, with all three given: one row per block and treatment, with the
  block in column `block`, the treatment in `treatment` and the score in
  `value`. The treatments are named by the values of the `treatment`
  column, and blocks and treatments are taken in the order they first
  appear.

A `missing` score, and a pair of block and treatment with no row, become
`NaN` and are rejected like any other `NaN`. A matrix with real elements
takes the matrix method instead; there is no `systems` argument here.

Throws an `ArgumentError` if `table` is not a table, if a column does not
exist, if the roles are given partly, or for the reasons of the matrix
method.

# Example

```julia
table = (topic=["t1", "t1", "t2", "t2", "t3", "t3"],
         system=["A", "B", "A", "B", "A", "B"],
         score=[0.1, 0.4, 0.2, 0.5, 0.15, 0.45])
randomized_tukey_hsd(table; trials=1_000, block=:topic, treatment=:system,
                     value=:score)
```
"""
function randomized_tukey_hsd(rng::AbstractRNG,
                              table;
                              trials::Integer,
                              block=nothing,
                              treatment=nothing,
                              value=nothing)
    (scores, treatments) = _table_scores(table, block, treatment, value)

    return randomized_tukey_hsd(rng, scores;
                                trials=trials,
                                systems=treatments)
end

function randomized_tukey_hsd(table; kwargs...)
    return randomized_tukey_hsd(Random.default_rng(), table; kwargs...)
end

# Arrange a table into a blocks × treatments matrix and the treatment
# names. `block`, `treatment` and `value` are column names or `nothing`;
# the docstring of the method above says what each combination means.
function _table_scores(table, block, treatment, value)
    if table isa AbstractMatrix
        msg = "a matrix must have real elements, got $(eltype(table)); " *
              "use NaN for a missing score"
        throw(ArgumentError(msg))
    end

    if !Tables.istable(table)
        msg = "expected a matrix or a Tables.jl table, got $(typeof(table))"
        throw(ArgumentError(msg))
    end

    columns = Tables.columns(table)
    available = collect(Tables.columnnames(columns))
    roles = (block=block, treatment=treatment, value=value)

    asked = Dict{Symbol,Symbol}()
    for (role, name) in pairs(roles)
        if name !== nothing
            asked[role] = Symbol(name)
            if !(asked[role] in available)
                msg = "no column $(repr(asked[role])) for the $role; " *
                      "columns are $(join(repr.(available), ", "))"
                throw(ArgumentError(msg))
            end
        end
    end

    if treatment === nothing && value === nothing
        return _wide_table(columns, available, get(asked, :block, nothing))
    end

    if length(asked) != 3
        msg = "for a tidy table give block, treatment and value; " *
              "for a wide one give none of them (or only block)"
        throw(ArgumentError(msg))
    end

    if length(unique(values(asked))) != 3
        msg = "block, treatment and value must be different columns, " *
              "got $(join(repr.(values(asked)), ", "))"
        throw(ArgumentError(msg))
    end

    return scores_matrix(Tables.getcolumn(columns, asked[:block]),
                         Tables.getcolumn(columns, asked[:treatment]),
                         Tables.getcolumn(columns, asked[:value]))
end

# Every column but `skipped` is a treatment.
function _wide_table(columns, available, skipped)
    treatments = Symbol[]
    for name in available
        if name != skipped
            push!(treatments, name)
        end
    end

    data = [ Tables.getcolumn(columns, name) for name in treatments ]

    return wide_scores(treatments, data)
end
