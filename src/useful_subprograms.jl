using ..BudgetedSearch
using ..HerbGrammar

function selector(results::Vector{Any})
  return results
end

function updater(results::Vector{Any}, iterator::ProgramIterator, grammar::ContextSensitiveGrammar)
  iter_grammar = get_grammar(iterator.solver)
  fragments = last(last(results))
  for fragment in fragments
    add_rule!(iter_grammar, rulenode2expr(fragment))
  end
  return iterator
end

"""
Iterates over and evaluates programs, mining fragments of those that passed
a subset of tests. 
"""
function synth_fn(
  problem::Problem,
  iterator::ProgramIterator,
)::Union{Tuple{RuleNode,SynthResult,Set{RuleNode}},Nothing}
  start_time = time()
  grammar = get_grammar(iterator.solver)
  symboltable::SymbolTable = SymbolTable(grammar)

  best_score = 0
  best_program = nothing

  fragments = Set{RuleNode}()

  # Find a way to keep simplest programs.

  for (i, candidate_program) ∈ enumerate(iterator)
    # Create expression from rulenode representation of AST
    expr = rulenode2expr(candidate_program, grammar)

    # Evaluate the expression
    # Don't want to short-circuit since subset of passed examples is useful
    passed_examples = evaluate(problem, expr, symboltable, shortcircuit=false, allow_evaluation_errors=true)
    score = count(passed_examples) / length(passed_examples)
    if score > 0
      # Mine fragments here
    fragments_of_program = mine_fragments(candidate_program)
    append!(fragments, fragments_of_program)

    if score == 1
      candidate_program = freeze_state(candidate_program)
      println(i)
      return (candidate_program, optimal_program, fragments)
    elseif score >= best_score
      best_score = score
      candidate_program = freeze_state(candidate_program)
      best_program = candidate_program
    end

    # Check stopping criteria
    if i > max_enumerations || time() - start_time > max_time
      break
    end
  end
  println(i)
  # The enumeration exhausted, but an optimal problem was not found
  return (best_program, suboptimal_program, fragments)
end

"""
    evaluate(problem::Problem{Vector{IOExample}}, expr::Any, tab::SymbolTable; allow_evaluation_errors::Bool=false)

Evaluate the expression on the examples.

Optional parameters:

    - `shortcircuit` - Whether to stop evaluating after finding single example fails, to speed up the [synth](@ref) procedure. If true, the returned score is an underapproximation of the actual score.
    - `allow_evaluation_errors` - Whether the search should continue if an exception is thrown in the evaluation or throw the error

Returns a BitVector of the examples that were fulfilled
"""
function evaluate(problem::Problem{Vector{IOExample}}, expr::Any, symboltable::SymbolTable; shortcircuit::Bool=true, allow_evaluation_errors::Bool=false)::Number
  passed_examples = BitVector(length(problem))

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
function mine_fragments(program::RuleNode)
  # For now just does depth first trasversal to add all nodes of the program tree to the fragment set
  fragments = Set{RuleNode}()
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
