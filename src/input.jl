"""
    tidy_matrix(blocks, treatments, responses)

Arrange tidy rows, one per block and treatment, into a blocks × treatments
matrix of `Float64`. The three vectors have the same length: row `i` says
that treatment `treatments[i]` had response `responses[i]` in block
`blocks[i]`.

Returns the matrix and the treatment names, one per column. Blocks and
treatments are in the order they first appear. A pair that has no row, and
a `missing` response, become `NaN`, which the test rejects.

Throws a `DimensionMismatch` if the vectors differ in length and an
`ArgumentError` if a block and treatment pair appears more than once.
"""
function tidy_matrix(blocks, treatments, responses)
    nrows = length(responses)
    if length(blocks) != nrows || length(treatments) != nrows
        msg = "$(length(blocks)) blocks, $(length(treatments)) treatments " *
              "and $nrows responses"
        throw(DimensionMismatch(msg))
    end

    block_index = Dict{eltype(blocks), Int}()
    treatment_index = Dict{eltype(treatments), Int}()
    names = eltype(treatments)[]
    rows = Vector{Int}(undef, nrows)
    cols = Vector{Int}(undef, nrows)

    # a new block or treatment gets the next number, one more than the
    # largest so far, so a single lookup says whether it was seen before
    nblocks = 0
    ntreatments = 0

    for (i, (block, treatment)) in enumerate(zip(blocks, treatments))
        row = get!(block_index, block, nblocks + 1)
        nblocks = max(nblocks, row)

        col = get!(treatment_index, treatment, ntreatments + 1)
        if col > ntreatments
            ntreatments = col
            push!(names, treatment)
        end

        rows[i] = row
        cols[i] = col
    end

    matrix = fill(NaN, nblocks, ntreatments)
    seen = falses(size(matrix))

    for i in 1:nrows
        if seen[rows[i], cols[i]]
            msg = "more than one response for block $(repr(blocks[i])) " *
                  "and treatment $(repr(treatments[i]))"
            throw(ArgumentError(msg))
        end

        seen[rows[i], cols[i]] = true
        if !ismissing(responses[i])
            matrix[rows[i], cols[i]] = responses[i]
        end
    end

    return (matrix, names)
end

"""
    wide_matrix(names, columns)

Arrange a wide table, one column of responses per treatment, into a
blocks × treatments matrix of `Float64`, one row per row of the table.
`names` are the treatment names and `columns` the columns, in the same
order. A `missing` response becomes `NaN`, which the test rejects.

Returns the matrix and the names. Throws a `DimensionMismatch` if the
columns differ in length or `names` and `columns` in number, and an
`ArgumentError` if a column is not numeric.
"""
function wide_matrix(names, columns)
    if length(names) != length(columns)
        msg = "$(length(names)) names for $(length(columns)) columns"
        throw(DimensionMismatch(msg))
    end

    nrows = isempty(columns) ? 0 : length(first(columns))
    matrix = fill(NaN, nrows, length(columns))

    for (j, column) in enumerate(columns)
        if length(column) != nrows
            msg = "column $(repr(names[j])) has $(length(column)) rows, " *
                  "not $nrows"
            throw(DimensionMismatch(msg))
        end

        if !(nonmissingtype(eltype(column)) <: Real)
            throw(ArgumentError("column $(repr(names[j])) is not numeric"))
        end

        for (i, response) in enumerate(column)
            if !ismissing(response)
                matrix[i, j] = response
            end
        end
    end

    return (matrix, collect(names))
end

# Arrange a table into a blocks × treatments matrix and the treatment
# names. `block`, `treatment` and `response` are column names or `nothing`;
# the docstring of `RandomizedTukeyProblem` says what each combination
# means.
function _table_responses(table, block, treatment, response)
    if table isa AbstractMatrix
        msg = "a matrix must have real elements, got $(eltype(table)); " *
              "use NaN for a missing response"
        throw(ArgumentError(msg))
    end

    if !Tables.istable(table)
        msg = "expected a matrix or a Tables.jl table, got $(typeof(table))"
        throw(ArgumentError(msg))
    end

    columns = Tables.columns(table)
    available = collect(Tables.columnnames(columns))
    roles = (block=block, treatment=treatment, response=response)

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

    if treatment === nothing && response === nothing
        return _wide_table(columns, available, get(asked, :block, nothing))
    end

    if length(asked) != 3
        msg = "for a tidy table give block, treatment and response; " *
              "for a wide one give none of them (or only block)"
        throw(ArgumentError(msg))
    end

    if length(unique(values(asked))) != 3
        msg = "block, treatment and response must be different columns, " *
              "got $(join(repr.(values(asked)), ", "))"
        throw(ArgumentError(msg))
    end

    return tidy_matrix(
        Tables.getcolumn(columns, asked[:block]),
        Tables.getcolumn(columns, asked[:treatment]),
        Tables.getcolumn(columns, asked[:response]),
    )
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

    return wide_matrix(treatments, data)
end
