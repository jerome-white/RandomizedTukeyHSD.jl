using
    CSV,
    ArgParse,
    DataFrames,
    Random,
    RandomizedTukeyHSD

function cliargs()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "input"
        help = "CSV file to read; - or nothing reads stdin"
        default = "-"

        "--trials", "-n", "--B"
        help = "Number of trials (--B is an alias)"
        dest_name = "trials"
        arg_type = Int
        required = true

        "--seed"
        help = "Seed for the random number generator (default: unseeded)"
        arg_type = Int

        "--format"
        help = "tidy: one row per block and treatment; wide: one " *
               "row per block, one column per treatment"
        arg_type = String
        default = "tidy"
        range_tester = x -> x in ("tidy", "wide")

        "--block"
        help = "Column that identifies the block (default: topic); with " *
               "--format wide, a column to leave out"
        arg_type = String

        "--treatment"
        help = "Column that identifies the treatment (default: system)"
        arg_type = String

        "--value"
        help = "Column with the score (default: score)"
        arg_type = String

        "--missing"
        help = "Topics with a missing or NaN score: error or drop"
        arg_type = String
        default = "error"
        range_tester = x -> x in ("error", "drop")
    end

    return parse_args(s)
end

args = cliargs()

#
# data aquisition
#
input = args["input"] == "-" ? stdin : args["input"]
df = DataFrame(CSV.File(read(input)))

if args["format"] == "tidy"
    (block, treatment, value) = RandomizedTukeyHSD.tidy_columns(
        names(df), args["block"], args["treatment"], args["value"]
    )
    (scores, systems) = RandomizedTukeyHSD.scores_matrix(df[!, block],
                                                         df[!, treatment],
                                                         df[!, value])
else
    for option in ("treatment", "value")
        if args[option] !== nothing
            error("--$option applies to --format tidy only")
        end
    end

    treatments = [ n for n in names(df) if n != args["block"] ]
    (scores, systems) = RandomizedTukeyHSD.wide_scores(
        treatments, [ df[!, n] for n in treatments ]
    )
end

#
# topics with a missing or NaN score
#
bad = RandomizedTukeyHSD.incomplete_topics(scores)
if any(bad)
    msg = "$(sum(bad)) of $(size(scores, 1)) topics have a missing or " *
          "NaN score"
    args["missing"] == "error" && error("$msg; use --missing drop")

    @warn "Dropping topics: $msg"
    scores = scores[.!bad, :]
    size(scores, 1) > 0 || error("no topics left")
end

#
# begin!
#
seed = args["seed"]
rng = seed === nothing ? Random.default_rng() : Xoshiro(seed)

@info "Settings" trials=args["trials"] seed

results = randomized_tukey_hsd(rng, scores;
                               trials=args["trials"],
                               systems=systems)

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
