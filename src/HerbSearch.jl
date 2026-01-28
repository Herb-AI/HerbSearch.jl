module HerbSearch

using DataStructures

using HerbCore
using HerbGrammar
using HerbConstraints
using HerbInterpret
using HerbSpecification
using MLStyle

using DocStringExtensions
using TimerOutputs

include("sampling_grammar.jl")

include("program_iterator.jl")
include("uniform_iterator.jl")

include("heuristics.jl")

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

include("sketch_learning/anti_unify.jl")
include("sketch_learning/anti_unify_utils.jl")
include("sketch_learning/terminal_hole_iterator.jl")

include("bottom_up_iterators/observational_equivalence.jl")
include("bottom_up_iterator.jl")
include("bottom_up_iterators/costbased_bus.jl")
include("bottom_up_iterators/shapebased_bus.jl")
# include("sketch_iterator.jl")

include("budgeted_search.jl")

# include("divide_conquer_functions/divide.jl")
# include("divide_conquer_functions/decide.jl")
# include("divide_conquer_functions/conquer.jl")

function divide_and_conquer end

export
    ProgramIterator,
    @programiterator, heuristic_leftmost,
    heuristic_rightmost,
    heuristic_random,
    heuristic_smallest_domain, derivation_heuristic, synth, synth_multi, synth_multi_with_state, get_solver,
    SynthResult,
    optimal_program,
    suboptimal_program, UniformIterator,
    next_solution!, TopDownIterator,
    RandomIterator,
    BFSIterator,
    DFSIterator,
    MLFSIterator, MHSearchIterator,
    VLSNSearchIterator,
    SASearchIterator, mean_squared_error,
    misclassification, GeneticSearchIterator,
    misclassification,
    validate_iterator,
    sample,
    rand,

    divide_and_conquer,
    EvaluationError,
    get_solver,

    BudgetedSearchController,
    run_budget_search,

    interpret_sygus_fn,

    anti_unify,
    collect_subtrees,
    count_nonhole_nodes,
    count_holes,
    passes_hole_thresholds,
    all_pairwise_anti_unification,
    anti_unify_patterns_and_tree,
    multi_MST_unify,
    anti_unify_programs,

    # Bottom-up Searches
    BottomUpState,
    BottomUpIterator,
    AbstractAddress,
    SizeBasedBottomUpIterator,
    DepthBasedBottomUpIterator,
    CostBasedBottomUpIterator,
    AccessAddress,
    CombineAddress,
    remaining_combinations,
    state_tracker,
    new_combinations!,
    new_state_tracker!,
    has_remaining_iterations,
    GenericBUState,
    populate_bank!,
    combine,
    add_to_bank!,
    new_address,
    retrieve,
    init_combine_structure,
    get_bank,
    enqueue_sketch_expansions!,
    print_sketch_stats,
    print_hash_rejection_stats,
    reset_sketch_counters!,
    

    TerminalHoleIterator,
    TerminalHoleSolver
end # module HerbSearch
