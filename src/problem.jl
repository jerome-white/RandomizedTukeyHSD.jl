"""
    RandomizedTukeyProblem(responses; treatments=axes(responses, 2))
    RandomizedTukeyProblem(table; block, treatment, response)

The data a randomized Tukey HSD test is run on, to be solved with
[`solve`](@ref) and a rule such as [`FixedTrials`](@ref). A problem says
what is tested and nothing about how: the number of trials and the random
number generator come in at `solve`.

The first form takes `responses`, a blocks × treatments matrix of real
numbers, and `treatments`, one name per column.

The second takes a [Tables.jl](https://tables.juliadata.org) table, such as a
`DataFrame`, so that the names of the treatments come with the data. The
shape is told by which of `block`, `treatment` and `response` are given; each
is the name of a column, as a `Symbol` or a `String`.

- **Wide**, with none given: each column is a treatment and each row a
  block. The treatments are named by the column names, as `Symbol`s, as the
  table gives them. Pass only `block` to leave out a column that identifies
  the rows.
- **Tidy**, with all three given: one row per block and treatment, with the
  block in column `block`, the treatment in `treatment` and the response in
  `response`. The treatments are named by the values of the `treatment`
  column, and blocks and treatments are taken in the order they first
  appear.

For a table, a `missing` response, and a pair of block and treatment with no
row, become `NaN` and are rejected like any other `NaN`. A matrix with real
elements takes the first form; a matrix of any other element type is
rejected as a table.

Throws an `ArgumentError` if there are fewer than two treatments, if
`responses` contains `NaN` (one `NaN` makes every p-value meaningless,
including those of pairs that do not involve its treatment), if `table` is
not a table, if a column does not exist, or if the roles are given partly;
and a `DimensionMismatch` if `treatments` does not have one name per column.

# Example

```julia
responses = [0.10 0.40 0.70; 0.20 0.50 0.60; 0.15 0.45 0.80; 0.25 0.35 0.65]
problem = RandomizedTukeyProblem(responses; treatments=["A", "B", "C"])

table = (block=["b1", "b1", "b2", "b2", "b3", "b3"],
         treatment=["A", "B", "A", "B", "A", "B"],
         response=[0.1, 0.4, 0.2, 0.5, 0.15, 0.45])
problem = RandomizedTukeyProblem(table; block=:block, treatment=:treatment,
                                 response=:response)
```
"""
struct RandomizedTukeyProblem{R<:AbstractMatrix{<:Real}, T<:AbstractVector}
    responses::R
    treatments::T

    function RandomizedTukeyProblem(responses::AbstractMatrix{<:Real},
                                    treatments::AbstractVector)
        ntreatments = size(responses, 2)

        if ntreatments <= 1
            throw(ArgumentError("need at least two treatments"))
        end
        if length(treatments) != ntreatments
            msg = "$(length(treatments)) treatment names for " *
                  "$ntreatments treatments"
            throw(DimensionMismatch(msg))
        end

        nans = count(isnan, responses)
        if nans != 0
            throw(ArgumentError("responses contain $nans NaN values"))
        end

        return new{typeof(responses), typeof(treatments)}(
            responses,
            treatments,
        )
    end
end

function RandomizedTukeyProblem(responses::AbstractMatrix{<:Real};
                                treatments::AbstractVector=axes(responses, 2))
    return RandomizedTukeyProblem(responses, treatments)
end

function RandomizedTukeyProblem(table;
                                block=nothing,
                                treatment=nothing,
                                response=nothing)
    (responses, treatments) = _table_responses(
        table,
        block,
        treatment,
        response,
    )

    return RandomizedTukeyProblem(responses; treatments=treatments)
end
