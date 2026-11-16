# Times the parts of one trial separately, and a whole run beside them, to
# show where the time of a trial goes. Run it from the repository root:
#
#   julia --project=benchmark -t 1 benchmark/parts.jl
#
# It prints a Markdown table in microseconds per trial: seeding the trial's
# stream, copying the observed responses, shuffling every block, the
# treatment means, their range, and `solve` as a whole (which also counts).
# The parts are the library's own internal functions, so the script follows
# the library. Each time is the least of five repetitions of a loop, and the
# script takes a few seconds.

using Printf
using Random
using RandomizedTukeyHSD

const SIZES = ((20, 3), (50, 5), (50, 20), (100, 20), (50, 100), (100, 100),
               (700, 50))

# Microseconds per repetition of `f(n)`, which repeats a part `n` times.
function per_repetition(f, n)
    f(2)
    best = minimum(@elapsed(f(n)) for _ in 1:5)

    return best / n * 1e6
end

function seeding(n)
    total = UInt64(0)
    for i in 1:n
        total += rand(RandomizedTukeyHSD._stream(UInt64(1), i), UInt64)
    end

    return total
end

function copying(data, observed, n)
    for _ in 1:n
        copyto!(data, observed)
    end
end

function shuffling(data, n)
    rng = Xoshiro(1)
    for _ in 1:n
        for col in eachcol(data)
            RandomizedTukeyHSD._shuffle!(rng, col)
        end
    end
end

function averaging(means, data, n)
    for _ in 1:n
        RandomizedTukeyHSD._row_means!(means, data)
    end
end

function ranging(means, n)
    total = 0.0
    for _ in 1:n
        (low, high) = extrema(means)
        total += high - low
    end

    return total
end

function solving(problem, n)
    solve(problem, FixedTrials(n); rng=Xoshiro(1))
end

function main()
    cpu = first(Sys.cpu_info())

    println("- Julia: ", VERSION)
    println("- CPU: ", cpu.model, " (", Sys.CPU_THREADS, " threads)")
    println("- Threads: ", Threads.nthreads())
    println("- Load average: ", join(round.(Sys.loadavg(); digits=2), " "))
    println()
    println("| blocks | treatments | seed | copy | shuffle | means | ",
            "range | solve |")
    println("|--:|--:|--:|--:|--:|--:|--:|--:|")

    seed = per_repetition(seeding, 20_000)

    for (nblocks, ntreatments) in SIZES
        rng = Xoshiro(ntreatments * 1_000_000 + nblocks)
        responses = rand(rng, nblocks, ntreatments)
        problem = RandomizedTukeyProblem(responses)

        # blocks in columns, as the library keeps them for a trial
        observed = Matrix{Float64}(transpose(responses))
        data = copy(observed)
        means = zeros(ntreatments)

        @printf("| %d | %d | %.2f | %.2f | %.2f | %.2f | %.3f | %.2f |\n",
                nblocks,
                ntreatments,
                seed,
                per_repetition(n -> copying(data, observed, n), 2_000),
                per_repetition(n -> shuffling(data, n), 2_000),
                per_repetition(n -> averaging(means, data, n), 2_000),
                per_repetition(n -> ranging(means, n), 100_000),
                per_repetition(n -> solving(problem, n), 5_000))
    end
end

main()
