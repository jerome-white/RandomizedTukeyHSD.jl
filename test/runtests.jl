using Test
using RandomizedTukeyHSD

include("helpers.jl")

@testset "RandomizedTukeyHSD" begin
    include("randomized_tukey.jl")
    include("reference.jl")
end
