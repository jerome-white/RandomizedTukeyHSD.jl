"""
    scores_matrix(topics, systems, scores)

Arrange tidy rows, one per topic and system, into a topics × systems
matrix of `Float64`. The three vectors have the same length: row `i` says
that system `systems[i]` scored `scores[i]` on topic `topics[i]`.

Returns the matrix and the system names, one per column. Topics and
systems are in the order they first appear. A pair that has no row, and a
`missing` score, become `NaN`, which the test rejects.

Throws a `DimensionMismatch` if the vectors differ in length and an
`ArgumentError` if a topic and system pair appears more than once.
"""
function scores_matrix(topics, systems, scores)
    nrows = length(scores)
    if length(topics) != nrows || length(systems) != nrows
        msg = "$(length(topics)) topics, $(length(systems)) systems and " *
              "$nrows scores"
        throw(DimensionMismatch(msg))
    end

    topic_index = Dict{eltype(topics),Int}()
    system_index = Dict{eltype(systems),Int}()
    names = eltype(systems)[]
    rows = Vector{Int}(undef, nrows)
    cols = Vector{Int}(undef, nrows)

    for i in 1:nrows
        rows[i] = get!(topic_index, topics[i], length(topic_index) + 1)

        if !haskey(system_index, systems[i])
            push!(names, systems[i])
        end
        cols[i] = get!(system_index, systems[i], length(system_index) + 1)
    end

    matrix = fill(NaN, length(topic_index), length(system_index))
    seen = falses(size(matrix))

    for i in 1:nrows
        if seen[rows[i], cols[i]]
            msg = "more than one score for topic $(repr(topics[i])) " *
                  "and system $(repr(systems[i]))"
            throw(ArgumentError(msg))
        end

        seen[rows[i], cols[i]] = true
        if !ismissing(scores[i])
            matrix[rows[i], cols[i]] = scores[i]
        end
    end

    return (matrix, names)
end

"""
    wide_scores(names, columns)

Arrange a wide table, one column of scores per treatment, into a
blocks × treatments matrix of `Float64`, one row per row of the table.
`names` are the treatment names and `columns` the columns, in the same
order. A `missing` score becomes `NaN`, which the test rejects.

Returns the matrix and the names. Throws a `DimensionMismatch` if the
columns differ in length or `names` and `columns` in number, and an
`ArgumentError` if a column is not numeric.
"""
function wide_scores(names, columns)
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

        for (i, score) in enumerate(column)
            if !ismissing(score)
                matrix[i, j] = score
            end
        end
    end

    return (matrix, collect(names))
end

# Arrange a table into a blocks × treatments matrix and the treatment
# names. `block`, `treatment` and `value` are column names or `nothing`;
# the docstring of `randomized_tukey_hsd` for tables says what each
# combination means.
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
