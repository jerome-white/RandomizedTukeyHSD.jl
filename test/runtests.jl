using Test
using RandomizedTukeyHSD

include("helpers.jl")

@testset "RandomizedTukeyHSD" begin
    include("randomized_tukey.jl")
    include("streams.jl")
    include("reference.jl")
    include("threads.jl")
    include("tables.jl")
    include("input.jl")
    include("table_input.jl")
    include("solve.jl")
    include("pvalue.jl")
end
