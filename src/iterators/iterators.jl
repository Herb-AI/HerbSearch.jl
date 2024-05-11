include("heuristics.jl")

# @programiterator macro include
include("program_iterator.jl")

include("fixed_shaped_iterator.jl")
include("top_down_iterator.jl")
include("uniform_iterator.jl")
include("random_iterator.jl")

include("genetic_iterator/genetic_iterator.jl")
include("stochastic_iterator/stochastic_iterator.jl")

include("meta_search/meta_search.jl")