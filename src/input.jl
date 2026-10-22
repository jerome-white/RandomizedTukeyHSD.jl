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
