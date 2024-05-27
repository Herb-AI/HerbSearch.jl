include("heuristics.jl")

# @programiterator macro include
include("program_iterator.jl")

"""
    set_start_program(iter::Itertor, start_program::RuleNode)

Sets the start program by subsituting the start program into the solver.
"""
function set_start_program!(iter::ProgramIterator, start_program::AbstractRuleNode) 
    substitute!(iter.solver, Vector{Int}(), start_program)
end


include("fixed_shaped_iterator.jl")
include("top_down_iterator.jl")
include("uniform_iterator.jl")
include("random_iterator.jl")

include("genetic_iterator/genetic_iterator.jl")
include("stochastic_iterator/stochastic_iterator.jl")

include("meta_search/meta_search.jl")