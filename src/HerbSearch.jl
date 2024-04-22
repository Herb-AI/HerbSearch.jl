module HerbSearch

using DataStructures

using HerbCore
using HerbGrammar
using HerbConstraints
using HerbSpecification
using HerbInterpret
using HerbSpecification
using MLStyle

include("sampling_grammar.jl")

include("program_iterator.jl")
include("uniform_iterator.jl")

include("heuristics.jl")

include("edit_distance.jl")
# TODO : Move to a different file
include("threads_helper.jl")
include("search_procedure.jl")

include("fixed_shaped_iterator.jl")
include("top_down_iterator.jl")

include("evaluate.jl")

include("stochastic_iterator.jl")
include("genetic_search/genetic_enumerators.jl")

include("meta_search/meta_runner.jl")
include("meta_search/run_algorithm.jl")

include("random_iterator.jl")

export 
  ProgramIterator,
  @programiterator,
  
  ContextSensitivePriorityEnumerator,
  
  heuristic_leftmost,
  heuristic_rightmost,
  heuristic_random,
  heuristic_smallest_domain,

  search_rulenode,
  search,
  search_best,
  supervised_search,
  meta_search,
  derivation_heuristic,

  synth,
  SynthResult,
  optimal_program,
  suboptimal_program,

  FixedShapedIterator,
  UniformIterator,
  next_solution!,

  TopDownIterator,
  RandomIterator,
  BFSIterator,
  DFSIterator,
  MLFSIterator,

  MHSearchIterator,
  VLSNSearchIterator,
  SASearchIterator,

  mean_squared_error,
  misclassification,

  GeneticSearchIterator,
  misclassification,
  validate_iterator,
  sample,
  rand,

  # meta search
  meta_grammar,
  generic_run,
  run_meta_search

# TODO: Don't export crossover_swap_children_2 and mutate_random!. It's a bit awkward
# TODO: Export the meta search grammar for testing.
end # module HerbSearch
