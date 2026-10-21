using
    CSV,
    ArgParse,
    DataFrames,
    Random,
    RandomizedTukeyHSD

function cliargs()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--B"
        help = "Number of replications"
        arg_type = Int
        required = true

        "--seed"
        help = "Seed for the random number generator (default: unseeded)"
        arg_type = Int

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
df = DataFrame(CSV.File(read(stdin)))
(scores, systems) = RandomizedTukeyHSD.scores_matrix(df.topic,
                                                     df.system,
                                                     df.score)

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

@info "Settings" B=args["B"] seed

results = randomized_tukey_hsd(rng, scores; B=args["B"], systems=systems)

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
