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

include("fragments/fragment_grammar_utils.jl")
include("fragments/mining_fragments.jl")

include("angelic_conditions/generate_angelic.jl")
include("angelic_conditions/angelic_replacement_strategies.jl")
include("angelic_conditions/long_hash_map.jl")

include("frangel/frangel.jl")
include("frangel/frangel_utils.jl")
include("frangel/frangel_generation.jl")
include("frangel/frangel_random_iterator.jl")


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

  FrAngelConfig,
  FrAngelConfigGeneration,
  frangel,

  replace_first_angelic!,
  replace_last_angelic!,

  generate_random_program,
  modify_and_replace_program_fragments!,
  add_angelic_conditions!,
  resolve_angelic!,

  mine_fragments,
  remember_programs!,
  
  add_fragments_prob!,
  setup_grammar_with_fragments!,
  add_fragment_base_rules!,
  add_fragment_rules!,
  updateGrammarWithFragments!,

  FrAngelRandomIterator,
  FrAngelRandomIteratorState,

  simplify_quick,
  _simplify_quick_once,
  symbols_minsize,
  rules_minsize,

  LongHashMap,
  init_long_hash_map,
  lhm_put!,
  lhm_contains
  
end # module HerbSearch
