using
    CSV,
    ArgParse,
    DataFrames,
    RandomizedTukeyHSD

function cliargs()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--B"
        help = "Number of replications"
        arg_type = Int
    end

    return parse_args(s)
end

args = cliargs()

#
# data aquisition
#
df = DataFrame(CSV.File(read(stdin)))
df = unstack(df, :topic, :system, :score)
select!(df, Not(:topic))

@info "Exploring:" args["B"] / factorial(ncol(df)) ^ nrow(df)

#
# begin!
#
results = randomized_tukey_hsd(Matrix{Float64}(df);
                               B=args["B"],
                               systems=names(df))

#
# report
#
results = DataFrame(results)
rename!(results, [
    :S1_name,
    :S2_name,
    :S1_mean,
    :S2_mean,
    :difference,
    :pvalue,
])
CSV.write(stdout, results)
