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
