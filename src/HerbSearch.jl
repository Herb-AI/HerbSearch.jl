module HerbSearch

using DataStructures

using HerbCore
using HerbGrammar
using HerbConstraints
using HerbSpecification
using HerbInterpret

include("sampling_grammar.jl")
include("enumerator_constructors.jl")

include("expression_iterator.jl")
include("count_expressions.jl")

include("csg_priority_enumerator.jl")
include("cfg_priority_enumerator.jl")

include("heuristics.jl")

include("edit_distance.jl")
include("meta_search/threads_helper.jl")
include("search_procedure.jl")

include("stochastic_search/stochastic_enumerators.jl")
include("genetic_search/genetic_enumerators.jl")

include("meta_search/meta_runner.jl")
include("meta_search/run_algorithm.jl")

export 
  count_expressions,
  ExpressionIterator,
  
  ContextSensitivePriorityEnumerator,
  ContextFreePriorityEnumerator,
  
  heuristic_leftmost,
  heuristic_rightmost,
  heuristic_random,
  heuristic_smallest_domain,

  search_rulenode,
  search,
  search_best,
  supervised_search,
  meta_search,

  bfs_priority_function,
  get_bfs_enumerator,
  get_mh_enumerator,
  get_vlsn_enumerator,
  get_sa_enumerator,
  get_genetic_enumerator,
  mean_squared_error,
  misclassification,
  mse_error_function,

  dfs_priority_function,
  get_dfs_enumerator,

  most_likely_priority_function,
  get_most_likely_first_enumerator,
  mutate_random!,
  crossover_swap_children_2,
  sample,
  rand,

  # meta search
  meta_grammar,
  generic_run,
  run_meta_search

# TODO: Don't export crossover_swap_children_2 and mutate_random!. It's a bit awkward
# TODO: Export the meta search grammar for testing.
end # module HerbSearch
