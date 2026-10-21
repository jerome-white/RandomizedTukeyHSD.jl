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
        required = true

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
df = unstack(df, :topic, :system, :score)
select!(df, Not(:topic))

#
# topics with a missing or NaN score
#
function incomplete(df)
    flags = Bool[]
    for row in eachrow(df)
        flag = any(x -> ismissing(x) || isnan(x), row)
        push!(flags, flag)
    end

    return flags
end

bad = incomplete(df)
if any(bad)
    msg = "$(sum(bad)) of $(nrow(df)) topics have a missing or NaN score"
    args["missing"] == "error" && error("$msg; use --missing drop")

    @warn "Dropping topics: $msg"
    df = df[.!bad, :]
    nrow(df) > 0 || error("no topics left")
end

#
# size of the space of arrangements, in logs: it does not fit in an Int
# (or a Float64) for realistic numbers of systems and topics
#
function log10_arrangements(nsystems, ntopics)
    perms = 0.0
    for n in 2:nsystems
        perms += log10(n)
    end

    return ntopics * perms
end

@info "Trials against arrangements" B=args["B"] log10_arrangements=round(
    log10_arrangements(ncol(df), nrow(df)); digits=2)

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
