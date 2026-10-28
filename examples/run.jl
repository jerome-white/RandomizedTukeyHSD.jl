# Reads a CSV of responses, runs the randomized Tukey HSD test and writes the
# results as CSV to stdout. An example of using the library from a script,
# not a supported tool.
#
#   julia --project=examples examples/run.jl data.csv 100000
#   julia --project=examples examples/run.jl data.csv 100000 1   # seeded
#
# The input has one row per block and treatment, with the columns named
# below (change them to match your file). For one row per block and one
# column per treatment, drop the keywords: RandomizedTukeyProblem(df).

using CSV, DataFrames, Random, RandomizedTukeyHSD

path = ARGS[1]
trials = parse(Int, ARGS[2])
rng = length(ARGS) > 2 ? Xoshiro(parse(Int, ARGS[3])) : Random.default_rng()

df = CSV.read(path, DataFrame)

problem = RandomizedTukeyProblem(df;
                                 block=:block,
                                 treatment=:treatment,
                                 response=:response)
results = solve(problem, FixedTrials(trials); rng=rng)

CSV.write(stdout, results)
