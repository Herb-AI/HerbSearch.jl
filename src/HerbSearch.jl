module HerbSearch

using DataStructures

using HerbCore
using HerbGrammar
using HerbConstraints
using HerbSpecification
using HerbInterpret
using HerbSpecification
using MLStyle

# import utilities first then iterators
include("utils/utils.jl")
include("iterators/iterators.jl")

include("evaluate.jl")
include("search_procedure.jl")

export 
  ProgramIterator,
  @programiterator,
  
  ContextSensitivePriorityEnumerator,
  
  heuristic_leftmost,
  heuristic_rightmost,
  heuristic_random,
  heuristic_smallest_domain,

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
  generic_meta_run,
  run_meta_search,
  evaluate_meta_program,
  VanillaIterator,
  SequenceCombinatorIterator,
  ParallelCombinatorIterator,
  ParallelNoThreads,
  ParallelThreads

# TODO: Don't export crossover_swap_children_2 and mutate_random!. It's a bit awkward
# TODO: Export the meta search grammar for testing.
end # module HerbSearch
