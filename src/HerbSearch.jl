module HerbSearch

using DataStructures

using HerbCore
using HerbGrammar
using HerbConstraints
using HerbInterpret
using HerbSpecification
using MLStyle

include("sampling_grammar.jl")

include("program_iterator.jl")
include("count_expressions.jl")

include("heuristics.jl")

include("top_down_iterator.jl")
include("stochastic_iterator.jl")

include("evaluate.jl")

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
  @programiterator,
  
  ContextSensitivePriorityEnumerator,
  
  heuristic_leftmost,
  heuristic_rightmost,
  heuristic_random,
  heuristic_smallest_domain,

  synth,
  SynthResult,
  optimal_program,
  suboptimal_program,

  TopDownIterator,
  BFSIterator,
  DFSIterator,
  MLFSIterator

  misclassification,
  mutate_random!,
  crossover_swap_children_2,
  sample,
  rand
end # module HerbSearch
