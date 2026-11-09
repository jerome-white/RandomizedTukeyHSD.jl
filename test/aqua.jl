using Aqua

# Aqua.jl is the community's package-quality check: method ambiguities,
# undefined exports, unbound type parameters, stale dependencies, compat
# bounds, type piracy and persistent tasks. Run all of its checks with
# their defaults; if a check ever has to be relaxed, pass that one keyword
# here with a comment saying why.
Aqua.test_all(RandomizedTukeyHSD)
