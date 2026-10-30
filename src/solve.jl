import CommonSolve

"""
    FixedTrials(trials)

The rule that runs exactly `trials` trials. In each trial the responses are
shuffled across treatments within every block, and the largest minus the
smallest treatment mean is recorded.

Throws an `ArgumentError` if `trials` is not positive.
"""
struct FixedTrials
    trials::Int

    function FixedTrials(trials::Integer)
        if trials <= 0
            throw(ArgumentError("trials must be positive, got $trials"))
        end

        return new(trials)
    end
end

"""
    RandomizedTukeyRun

A [`RandomizedTukeyProblem`](@ref) being solved with a rule: what `init`
returns, `step!` advances and `solve!` finishes.

Besides the problem, the rule and the generator, a run keeps what the
trials so far have shown, so that nothing but counts is stored: for every
pair of treatments, the number of trials whose range reached the pair's
observed absolute difference in means. [`trials`](@ref) says how many
trials that is out of, and [`pvalues`](@ref) turns the counts into
[`MonteCarloPValue`](@ref)s.

Every trial has its own random stream, which depends on a base seed drawn
from the generator when the run is made and on the number of the trial. So
the trials do not depend on how they are cut into chunks, which only says how
`step!` schedules them, nor on the number of threads.
"""
mutable struct RandomizedTukeyRun{
    P<:RandomizedTukeyProblem, L, G<:AbstractRNG, M
}
    problem::P
    rule::L
    rng::G
    chunk::Int
    base::UInt64
    monitor::M
    interval::Int
    pairs::Vector{Tuple{Int, Int}}
    means::Vector{Float64}
    observed::Vector{Float64}
    exceeding::Vector{Int}
    chunks::Int
    trials::Int
end

"""
    init(problem::RandomizedTukeyProblem, rule;
         rng=Random.default_rng(), monitor=NoMonitor(), every=nothing)

Prepare to solve `problem` with `rule` (for now [`FixedTrials`](@ref)),
drawing the trials from `rng`. Returns a [`RandomizedTukeyRun`](@ref) with no
trials done, for `step!` or `solve!`.

One base seed is drawn from `rng` here and nothing is drawn later, so `rng`
has advanced by the time `init` returns, whatever `step!` does.

`monitor` is shown a [`Checkpoint`](@ref) by `solve!` every `every` trials
(rounded up to whole chunks of 64) and at the end; see [`emit`](@ref) for what
a monitor is. Without `every`, the checkpoints are about 1% of the rule's
trials apart. With the default [`NoMonitor`](@ref) there is no checkpoint
but the last, and `solve!` runs all its trials in one go. The monitor and
`every` change nothing in the results.

Throws an `ArgumentError` if `every` is not positive.
"""
function CommonSolve.init(problem::RandomizedTukeyProblem,
                          rule::FixedTrials;
                          rng::AbstractRNG=Random.default_rng(),
                          monitor=NoMonitor(),
                          every::Union{Nothing, Integer}=nothing)
    return _init(problem, rule, rng; monitor=monitor, every=every)
end

# The trials between checkpoints when `every` is not given: all of them for
# no monitor, which needs none, and about 1% of the rule's for any other.
function _default_every(::NoMonitor, rule)
    return rule.trials
end

function _default_every(monitor, rule)
    return cld(rule.trials, 100)
end

# `chunk` is the number of trials per task. It only schedules the work: the
# results do not depend on it.
function _init(problem, rule::FixedTrials, rng, chunk=64;
               monitor=NoMonitor(), every=nothing)
    if every !== nothing && every <= 0
        throw(ArgumentError("every must be positive, got $every"))
    end
    if every === nothing
        every = _default_every(monitor, rule)
    end

    responses = problem.responses
    means = vec(mean(responses; dims=1))
    pairs = _pairs(length(means))

    observed = Vector{Float64}(undef, length(pairs))
    for (p, (j, k)) in enumerate(pairs)
        observed[p] = abs(means[j] - means[k])
    end

    base = rand(rng, UInt64)
    exceeding = zeros(Int, length(pairs))

    return RandomizedTukeyRun(
        problem,
        rule,
        rng,
        chunk,
        base,
        monitor,
        cld(every, chunk),
        pairs,
        means,
        observed,
        exceeding,
        0,
        0,
    )
end

"""
    trials(run::RandomizedTukeyRun)

The number of trials `run` has done so far.
"""
function trials(run::RandomizedTukeyRun)
    return run.trials
end

"""
    pvalues(run::RandomizedTukeyRun)

The p-value of every pair of treatments so far, in the order of the pairs of
`solve!` ((1,2), (1,3), ..., (n-1,n)), as [`MonteCarloPValue`](@ref)s, which
keep the number of trials they come from.

Throws an `ArgumentError` if no trials have been done.
"""
function pvalues(run::RandomizedTukeyRun)
    if run.trials == 0
        throw(ArgumentError("no trials done yet; call step!"))
    end

    result = MonteCarloPValue[]
    sizehint!(result, length(run.pairs))
    for exceeding in run.exceeding
        push!(result, MonteCarloPValue(exceeding, run.trials))
    end

    return result
end

# Number of chunks the rule plans.
function _planned(run)
    return cld(run.rule.trials, run.chunk)
end

# Number of trials of chunk `c`: all of them are `run.chunk` but the last.
function _chunk_trials(run, c)
    planned = run.rule.trials
    first = (c - 1) * run.chunk + 1
    last = min(c * run.chunk, planned)

    return last - first + 1
end

# Run chunk `c` and add to `exceeding`, for every pair, the number of its
# trials whose range reached the pair's observed difference.
function _count_chunk!(exceeding, run, c, lck)
    ranges = Vector{Float64}(undef, _chunk_trials(run, c))
    first = (c - 1) * run.chunk + 1
    _trials!(ranges, run.problem.responses, run.base, first)
    sort!(ranges)

    counts = Vector{Int}(undef, length(run.observed))
    for (p, difference) in enumerate(run.observed)
        counts[p] = length(ranges) - searchsortedfirst(ranges, difference) + 1
    end

    lock(lck) do
        exceeding .+= counts
    end

    return nothing
end

"""
    step!(run::RandomizedTukeyRun, nchunks=1)

Advance `run` by `nchunks` chunks of trials (64 trials each, but for the
last chunk of the rule), in parallel on the available threads. Returns `run`.

The counts do not depend on the order the chunks finish in, so they do not
depend on the number of threads either: adding whole numbers is exact.

Throws an `ArgumentError` if `nchunks` is not positive or is more than the
rule has left.
"""
function CommonSolve.step!(run::RandomizedTukeyRun, nchunks::Integer=1)
    if nchunks <= 0
        throw(ArgumentError("nchunks must be positive, got $nchunks"))
    end
    left = _planned(run) - run.chunks
    if nchunks > left
        msg = "$nchunks chunks asked for, but $left left"
        throw(ArgumentError(msg))
    end

    first = run.chunks + 1
    last = run.chunks + nchunks
    lck = ReentrantLock()
    exceeding = zeros(Int, length(run.exceeding))

    @sync for c in first:last
        @spawn _count_chunk!(exceeding, run, c, lck)
    end

    run.exceeding .+= exceeding
    run.chunks = last
    run.trials = min(last * run.chunk, run.rule.trials)

    return run
end

"""
    solve!(run::RandomizedTukeyRun)
    solve(problem::RandomizedTukeyProblem, rule; rng=Random.default_rng())

Randomized Tukey HSD test over all pairs of treatments: `step!` until the rule
is done, then report. `solve` is `solve!(init(problem, rule; rng))`.

A pair's p-value is the fraction of trials whose range is at least the pair's
observed absolute difference in means. A p-value of 0 means no trial reached
the difference, that is, p < 1/`trials`. `rng` is the random number generator
the trials are drawn from (the global one if left out). With the same `rng`
state, `trials`, responses and Julia version the p-values are the same at any
number of threads.

Returns one named tuple per pair of treatments, in the order (1,2), (1,3),
..., (n-1,n), with fields `treatment1`, `treatment2`, `mean1`, `mean2`,
`difference` (`mean1 - mean2`) and `pvalue`. A vector of named tuples is a
Tables.jl table. To have the p-values with the number of trials they come
from, see [`pvalues`](@ref).

# Example

```julia
using Random
responses = [0.10 0.40 0.70; 0.20 0.50 0.60; 0.15 0.45 0.80; 0.25 0.35 0.65]
problem = RandomizedTukeyProblem(responses; treatments=["A", "B", "C"])
results = solve(problem, FixedTrials(10_000); rng=Xoshiro(1))
results[2].pvalue   # A against C
```
"""
function CommonSolve.solve!(run::RandomizedTukeyRun{P, FixedTrials}) where P
    while run.chunks < _planned(run)
        left = _planned(run) - run.chunks
        step!(run, min(run.interval, left))
        _notify(run.monitor, run)
    end

    return _results(run)
end

# Show the monitor the state of the run: a copy, never the run.
function _notify(monitor, run)
    done = run.chunks == _planned(run)
    checkpoint = Checkpoint(run.trials, run.rule.trials, pvalues(run), done)
    emit(monitor, checkpoint)

    return nothing
end

function _notify(::NoMonitor, run)
    return nothing
end

# The named tuples of `solve!`, from the counts so far.
function _results(run)
    treatments = run.problem.treatments

    results = map(enumerate(run.pairs)) do (p, (j, k))
        (treatment1=treatments[j],
         treatment2=treatments[k],
         mean1=run.means[j],
         mean2=run.means[k],
         difference=run.means[j] - run.means[k],
         pvalue=run.exceeding[p] / run.trials)
    end

    return results
end
