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

include("fixed_shaped_iterator.jl")
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

include("frangel/frangel.jl")
include("frangel/frangel_utils.jl")

export 
  ProgramIterator,
  @programiterator,
  
  ContextSensitivePriorityEnumerator,
  
  heuristic_leftmost,
  heuristic_rightmost,
  heuristic_random,
  heuristic_smallest_domain,

  derivation_heuristic,

  synth,
  SynthResult,
  optimal_program,
  suboptimal_program,

  FixedShapedIterator, #TODO: deprecated after the cp thesis
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

  frangel,
  
  mean_squared_error,
  misclassification,

  GeneticSearchIterator,
  misclassification,
  validate_iterator,
  sample,
  rand,

  mine_fragments,
  remember_programs!,
  count_nodes,

  FrAngelConfig,
  FrAngelIterator,
  FrAngelIteratorState,

  get_passed_tests,
  generate_random_program,
  random_partition,
  random_modify_children!,

  rules_minsize,
  symbols_minsize,
  simplify_quick,
  _simplify_quick_once

  get_replacements,
  get_descendant_replacements!,
  passes_the_same_tests_or_more,
  resolve_angelic!

end # module HerbSearch
