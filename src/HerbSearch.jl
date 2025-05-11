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
include("uniform_iterator.jl")

include("heuristics.jl")

include("bottom_up_iterators/observational_equivalence.jl")
include("bottom_up_iterators/rulenode_combinations.jl")
include("bottom_up_iterators/cross_product_iterator.jl")
include("bottom_up_iterators/abstract_rulenode_iterator.jl")
include("bottom_up_iterators/bottom_up_iterator.jl")
include("bottom_up_iterators/bottom_up_depth_iterator.jl")
include("bottom_up_iterators/bounded_iterator.jl")
include("bottom_up_iterators/depth_bounded_iterator.jl")
include("bottom_up_iterators/size_bounded_iterator.jl")

include("top_down_iterator.jl")

include("evaluate.jl")

include("search_procedure.jl")

include("stochastic_iterator.jl")
include("stochastic_functions/cost_functions.jl")
include("stochastic_functions/neighbourhood.jl")
include("stochastic_functions/propose.jl")
include("stochastic_functions/accept.jl")
include("stochastic_functions/temperature.jl")

include("genetic_functions/fitness.jl")
include("genetic_functions/mutation.jl")
include("genetic_functions/crossover.jl")
include("genetic_functions/select_parents.jl")
include("genetic_search_iterator.jl")

include("random_iterator.jl")

export 
  ProgramIterator,
  @programiterator,
  
  heuristic_leftmost,
  heuristic_rightmost,
  heuristic_random,
  heuristic_smallest_domain,

  derivation_heuristic,

  synth,
  SynthResult,
  optimal_program,
  suboptimal_program,

  UniformIterator,
  next_solution!,

  TopDownIterator,
  RandomIterator,
  BFSIterator,
  DFSIterator,
  MLFSIterator,

  BottomUpIterator,
  BUDepthIterator,
  BURulenodeIterator,
  BUUniformIterator,
  Bounded_BU_Iterator,
  DepthBoundedIterator,
  SizeBoundedIterator,

  MHSearchIterator,
  VLSNSearchIterator,
  SASearchIterator,

  mean_squared_error,
  misclassification,

  GeneticSearchIterator,
  misclassification,
  validate_iterator,
  sample,
  rand
end # module HerbSearch
