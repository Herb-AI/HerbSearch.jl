module UsefulSubprograms

export UsefulSubprograms

using ..BudgetedSearch
using HerbGrammar
using HerbCore
using HerbInterpret
using HerbSpecification
using HerbConstraints

import ..HerbSearch: optimal_program, suboptimal_program, SynthResult, ProgramIterator,
  get_grammar, get_max_size, EvaluationError, BFSIterator

function selector(results::Vector{Any})
  return results
end

function updater(results::Vector{Any}, iterator::ProgramIterator, grammar::ContextSensitiveGrammar)
  iter_grammar = get_grammar(iterator.solver)
  updated_grammar = deepcopy(iter_grammar)

  fragments = last(last(results))

  for fragment in fragments
    if fragment isa RuleNode
      add_rule!(updated_grammar, fragment)
    end
  end

  #reconstruct the iterator with the new grammar 
  root_hole = iterator.solver.state.tree
  first_rule_index = findfirst(root_hole.domain)
  start_symbol = iter_grammar.types[first_rule_index]

  new_iterator = BFSIterator(
    updated_grammar,
    start_symbol;
    max_depth=iterator.solver.max_depth,
    max_size=iterator.solver.max_size
  )

  return new_iterator
end

"""
Iterates over and evaluates programs, mining fragments of those that passed
a subset of tests. 
"""
function synth_fn(
  problem::Problem,
  iterator::ProgramIterator,
)::Union{Tuple{AbstractRuleNode,SynthResult,Set{AbstractRuleNode}},Nothing}
  start_time = time()
  grammar = get_grammar(iterator.solver)
  symboltable::SymbolTable = grammar2symboltable(grammar)

  best_score = 0
  best_program = nothing

  fragments = Set{AbstractRuleNode}()

  for (i, candidate_program) ∈ enumerate(iterator)
    expr = rulenode2expr(candidate_program, grammar)

    # Don't want to short-circuit since subset of passed examples is useful
    passed_examples = evaluate(problem, expr, symboltable, shortcircuit=false, allow_evaluation_errors=true)
    score = count(passed_examples) / length(passed_examples)
    if score > 0
      fragments_of_program = mine_fragments(freeze_state(candidate_program))
      union!(fragments, fragments_of_program)
    end

    if score == 1
      candidate_program = freeze_state(candidate_program)
      println("Found optimal solution at iteration: ", i)
      return (candidate_program, optimal_program, fragments)
    elseif score >= best_score
      best_score = score
      candidate_program = freeze_state(candidate_program)
      best_program = candidate_program
    end

    # Check stopping criteria (get from iterator if available)
    max_enumerations = get_max_size(iterator)
    max_time = typemax(Int)  # No time limit for now
    if i > max_enumerations || time() - start_time > max_time
      break
    end
  end
  println(i)
  # The enumeration exhausted, but an optimal problem was not found
  return (best_program, suboptimal_program, fragments)
end

"""
Returns a BitVector of the examples that were fulfilled
"""
function evaluate(problem::Problem, expr::Any, symboltable::SymbolTable; shortcircuit::Bool=true, allow_evaluation_errors::Bool=false)::BitVector
  passed_examples = falses(length(problem.spec))

  crashed = false
  for (i, example) ∈ enumerate(problem.spec)
    try
      output = execute_on_input(symboltable, expr, example.in)
      if (output == example.out)
        passed_examples[i] = true
      elseif (shortcircuit)
        break
      end
    catch e
      # You could also decide to handle less severe errors (such as index out of range) differently,
      # for example by just increasing the error value and keeping the program as a candidate.
      crashed = true
      # Throw the error again if evaluation errors aren't allowed
      eval_error = EvaluationError(expr, example.in, e)
      allow_evaluation_errors || throw(eval_error)
      break
    end
  end

  return passed_examples
end

"""
Returns a Set{RuleNode} of all the fragments of the passed program 
"""
function mine_fragments(program::AbstractRuleNode)
  # For now just does depth first trasversal to add all nodes of the program tree to the fragment set
  fragments = Set{AbstractRuleNode}()
  stack = [program]
  while !isempty(stack)
    current_node = pop!(stack)
    push!(fragments, current_node)
    for child in current_node.children
      push!(stack, child)
    end
  end

  return fragments
end
end
