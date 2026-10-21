"""
    scores_matrix(topics, systems, scores)

Arrange tidy rows, one per topic and system, into a topics × systems
matrix of `Float64`. The three vectors have the same length: row `i` says
that system `systems[i]` scored `scores[i]` on topic `topics[i]`.

Returns the matrix and the system names, one per column. Topics and
systems are in the order they first appear. A pair that has no row, and a
`missing` score, become `NaN`, so `incomplete_topics` finds them.

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
    incomplete_topics(scores)

A `Vector{Bool}` with one entry per row (topic) of `scores`, `true` where
the topic has a `NaN` in any system. Remove those topics with
`scores[.!incomplete_topics(scores), :]`: every system is then still
averaged over the same topics.
"""
function incomplete_topics(scores::AbstractMatrix{<:Real})
    flags = Bool[]

    for row in eachrow(scores)
        flag = any(isnan, row)
        push!(flags, flag)
    end

    return flags
end
