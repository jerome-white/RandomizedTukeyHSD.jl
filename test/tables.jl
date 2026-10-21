using Tables

# the library does not depend on Tables: a vector of named tuples is already
# a Tables.jl table, which is what DataFrames, CSV and others consume
@testset "Tables.jl interface" begin
    Random.seed!(1)
    results = randomized_tukey_hsd(SCORES; trials=100, systems=NAMES)
    fields = (:system1, :system2, :mean1, :mean2, :difference, :pvalue)

    @test Tables.istable(results)
    @test Tables.rowaccess(results)
    @test Tables.schema(results).names == fields
    @test Tables.schema(results).types ==
        (String, String, Float64, Float64, Float64, Float64)

    columns = Tables.columntable(results)
    @test keys(columns) == fields
    @test columns.system1 == ["A", "A", "B"]
    @test columns.pvalue == [ r.pvalue for r in results ]
end
