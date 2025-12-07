module UsefulSubprograms

export UsefulSubprograms

using HerbGrammar
using HerbCore
using HerbInterpret
using HerbSpecification
using HerbConstraints

import ..HerbSearch: optimal_program, suboptimal_program, SynthResult, ProgramIterator,
  get_grammar, get_max_size, EvaluationError, BFSIterator, get_starting_symbol, BudgetedSearchController


function selector(results::Vector{Any})
  # Here I will insert elements of the latest results array into the previous one and update the grammar based on that.
  if length(results) < 2
    return last(results)
  else
    prev_result = results[end-1]
    curr_result = results[end]
    for idx in eachindex(prev_result[3])
      if isassigned(prev_result[3], idx) && (length(prev_result[3][idx]) < length(curr_result[3][idx]))
        curr_result[3][idx] = prev_result[3][idx]
      end
    end
    # results[end] = curr_result
    return curr_result
  end
  # This should also work for the removal of elements from the grammar
end

function updater(results::Tuple{RuleNode,SynthResult,Vector{AbstractRuleNode}}, iterator::ProgramIterator)
  # The latest array in results will contain the simplest subprograms array that matches the latest run.
  iter_grammar = get_grammar(iterator.solver)

  fragments = last(results)

  for idx in eachindex(fragments)
    if isassigned(fragments, idx) && fragments[idx] isa RuleNode
      add_rule!(iter_grammar, fragments[idx])
    end
  end

  IterType = typeof(iterator)
  new_iterator = IterType(
    iter_grammar,
    get_starting_symbol(iterator.solver),
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
  problem::Problem, iterator::ProgramIterator)::Union{Tuple{AbstractRuleNode,SynthResult,Vector{AbstractRuleNode}},Nothing}
  start_time = time()
  grammar = get_grammar(iterator.solver)
  symboltable::SymbolTable = grammar2symboltable(grammar)

  best_score = 0
  best_program = nothing

  #fragments = Set{AbstractRuleNode}()
  simplest_subprograms = Vector{AbstractRuleNode}(undef, 2^length(problem.spec))

  for (i, candidate_program) ∈ enumerate(iterator)
    expr = rulenode2expr(candidate_program, grammar)

    # Don't want to short-circuit since subset of passed examples is useful
    passed_examples = evaluate(problem, expr, symboltable, shortcircuit=false, allow_evaluation_errors=true)
    idx = bitvec_to_idx(passed_examples)
    if !isassigned(simplest_subprograms, idx)
      simplest_subprograms[idx] = freeze_state(candidate_program)
      println("bitvec idx", idx)
    elseif isassigned(simplest_subprograms, idx)
      if length(candidate_program) < length(simplest_subprograms[idx])
        simplest_subprograms[idx] = freeze_state(candidate_program)
      end
    end
    score = count(passed_examples) / length(passed_examples)
    # if score > 0
    #   fragments_of_program = mine_fragments(freeze_state(candidate_program))
    #   union!(fragments, fragments_of_program)
    # end

    if score == 1
      candidate_program = freeze_state(candidate_program)
      println("Found optimal solution at iteration: ", i)
      return (candidate_program, optimal_program, simplest_subprograms)
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
  return (best_program, suboptimal_program, simplest_subprograms)
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
  push!(fragments, program)
  # stack = [program]
  # while !isempty(stack)
  #   current_node = pop!(stack)
  #   push!(fragments, current_node)
  #   for child in current_node.children
  #     push!(stack, child)
  #   end
  # end

  return fragments
end

function bitvec_to_idx(bv::BitVector)::Int64
  sum = 1
  for pos in eachindex(bv)
    sum += bv[pos] * 2^(pos - 1)
  end
  return sum
end
end
