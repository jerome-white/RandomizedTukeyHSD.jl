# Benchmarks randomized_tukey_hsd over a grid of problem sizes and prints
# a Markdown table. Run it from the repository root:
#
#   julia --project=benchmark -t 1 benchmark/randomized_tukey.jl
#   julia --project=benchmark -t 4 benchmark/randomized_tukey.jl
#
# The scores are random but seeded, so every run sees the same data.

using BenchmarkTools
using Printf
using Random
using RandomizedTukeyHSD

const SYSTEMS = (5, 10, 20)
const TOPICS = (50, 100)
const TRIALS = (1_000, 10_000)

function environment()
    cpu = first(Sys.cpu_info())

    println("- Julia: ", VERSION)
    println("- CPU: ", cpu.model, " (", Sys.CPU_THREADS, " threads)")
    println("- Threads: ", Threads.nthreads(), " default, ",
            Threads.nthreads(:interactive), " interactive")
    println("- Load average: ", join(round.(Sys.loadavg(); digits=2), " "))
end

function measure(nsystems, ntopics, B)
    rng = Xoshiro(nsystems * 1_000_000 + ntopics)
    scores = rand(rng, ntopics, nsystems)

    # compile and warm up outside the measurement
    randomized_tukey_hsd(scores; B=10)

    return @benchmark(
        randomized_tukey_hsd($scores; B=$B),
        samples=10,
        seconds=60,
        evals=1
    )
end

function main()
    environment()
    println()
    println("| systems | topics | B | median (ms) | us/trial | ",
            "min (ms) | MiB | allocs |")
    println("|--:|--:|--:|--:|--:|--:|--:|--:|")

    for nsystems in SYSTEMS, ntopics in TOPICS, B in TRIALS
        trial = measure(nsystems, ntopics, B)
        median_ns = time(median(trial))
        @printf("| %d | %d | %d | %.1f | %.2f | %.1f | %.1f | %d |\n",
                nsystems,
                ntopics,
                B,
                median_ns / 1e6,
                median_ns / 1e3 / B,
                time(minimum(trial)) / 1e6,
                trial.memory / 2^20,
                trial.allocs)
    end
end

main()
