module HerbSearch

using DataStructures

using HerbCore
using HerbGrammar
using HerbConstraints
using HerbData
using HerbInterpret

include("sampling_grammar.jl")
include("enumerator_constructors.jl")

include("program_iterator.jl")
include("count_expressions.jl")

include("top_down_search_strategies.jl")
include("top_down_iterator.jl")

include("heuristics.jl")

include("stochastic_search_strategies.jl")
include("stochastic_iterator.jl")

include("search_procedure.jl")
include("stochastic_functions/cost_functions.jl")

include("stochastic_functions/neighbourhood.jl")
include("stochastic_functions/propose.jl")
include("stochastic_functions/accept.jl")
include("stochastic_functions/temperature.jl")
include("stochastic_enumerators.jl")

include("genetic_functions/fitness.jl")
include("genetic_functions/mutation.jl")
include("genetic_functions/crossover.jl")
include("genetic_functions/select_parents.jl")
include("genetic_search_iterator.jl")
include("genetic_enumerators.jl")

export 
  count_expressions,
  ProgramIterator,
  
  ContextSensitivePriorityEnumerator,
  ContextFreePriorityEnumerator,
  
  heuristic_leftmost,
  heuristic_rightmost,
  heuristic_random,
  heuristic_smallest_domain,

  search_rulenode,
  search,
  search_best,

  BreadthFirstSearchStrategy,
  DepthFirstSearchStrategy,
  MostLikelyFirstSearchStrategy,

  TopDownIterator,

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
  rand
end # module HerbSearch
