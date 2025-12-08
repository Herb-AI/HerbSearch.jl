module UsefulSubprograms

export UsefulSubprograms

using HerbGrammar
using HerbCore
using HerbInterpret
using HerbSpecification
using HerbConstraints

import ..HerbSearch: optimal_program, suboptimal_program, SynthResult, ProgramIterator,
  get_grammar, get_max_size, EvaluationError, BFSIterator, get_starting_symbol, BudgetedSearchController


@kwdef mutable struct BankEntry
  remembered_program::AbstractRuleNode
  grammar_rule_idx::Union{Nothing,Int}
  has_been_updated::Bool
end

function stop_checker(timed_solution)::Bool
  return timed_solution[2] == optimal_program
end

# initializes entries as undefined BankEntries, they are assigned during execution of the selector and updater functions
function init_bank(problem::Problem, iterator::ProgramIterator)::Dict{Int,BankEntry}
  bank = Dict{Int, BankEntry}()
  return bank
end

function selector(solution::Tuple{AbstractRuleNode,SynthResult,Dict{Int,AbstractRuleNode}}, bank::Dict{Int,BankEntry})
  # Here I will insert elements of the latest results array into the previous one and update the grammar based on that.
  # The bank is updated based on the result of the synth_fn. Only the programs are updates, not the corresponding grammar rules
  found_programs = solution[3]
  for idx in eachindex(bank)
    if isassigned(bank, idx)
      # edit already remembered subprogram
      if !isnothing(found_programs[idx]) && isassigned(found_programs, idx) && length(found_programs[idx]) < length(bank[idx].remembered_program)
        bank[idx].remembered_program = found_programs[idx]
        bank[idx].has_been_updated = true
      end
    elseif isassigned(found_programs, idx)
      # Add new subprogram to the remembered_subprograms bank
      bank[idx] = BankEntry(found_programs[idx], nothing, false)
    end
  end
  # results[end] = curr_result
  return solution
  # This should also work for the removal of elements from the grammar
end

function updater(selected::Tuple{RuleNode,SynthResult,Dict{Int,AbstractRuleNode}}, iterator::ProgramIterator, bank::Dict{Int,BankEntry})
  # The latest array in results will contain the simplest subprograms array that matches the latest run.
  iter_grammar = get_grammar(iterator.solver)

  for idx in eachindex(bank)
    if !haskey(bank, idx)
      continue
    end
    if bank[idx].has_been_updated
      # updates the rule stored at the index (since a simpler program has been found)
      updated_rule = rulenode2expr(bank[idx].remembered_program, iter_grammar)
      iter_grammar.rules[bank[idx].grammar_rule_idx] = updated_rule
      bank[idx].has_been_updated = false
    elseif isnothing(bank[idx].grammar_rule_idx)
      # add a grammar rule and store the index
      add_rule!(iter_grammar, bank[idx].remembered_program)
      bank[idx].grammar_rule_idx = length(iter_grammar.rules)
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
  problem::Problem, iterator::ProgramIterator)::Union{Tuple{AbstractRuleNode,SynthResult,Dict{Int,AbstractRuleNode}},Nothing}
  start_time = time()
  grammar = get_grammar(iterator.solver)
  symboltable::SymbolTable = grammar2symboltable(grammar)

  best_score = 0
  best_program = nothing
  num_iterations = 0

  #fragments = Set{AbstractRuleNode}()
  simplest_subprograms = Dict{Int,AbstractRuleNode}()

  for (i, candidate_program) ∈ enumerate(iterator)
    num_iterations = i
    expr = rulenode2expr(candidate_program, grammar)

    # Don't want to short-circuit since subset of passed examples is useful
    passed_examples = evaluate(problem, expr, symboltable, shortcircuit=false, allow_evaluation_errors=true)
    idx = bitvec_to_idx(passed_examples)
    if !haskey(simplest_subprograms, idx)
      simplest_subprograms[idx] = freeze_state(candidate_program)
    elseif haskey(simplest_subprograms, idx)
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
  println(num_iterations)
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
