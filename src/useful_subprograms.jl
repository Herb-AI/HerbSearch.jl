module UsefulSubprograms

export UsefulSubprograms

using HerbGrammar
using HerbCore
using HerbInterpret
using HerbSpecification
using HerbConstraints

import ..HerbSearch: optimal_program, suboptimal_program, SynthResult, ProgramIterator,
  get_grammar, get_max_size, EvaluationError, BFSIterator, get_starting_symbol,
  BudgetedSearchController, CostBasedBottomUpIterator, get_costs, get_bank,
  inner_bank, get_entries, get_types, get_measures, GenericBUState

# Id of each bank entry corresponds to a bitvector of passed examples
@kwdef mutable struct BankEntry
  remembered_program::AbstractRuleNode
  grammar_rule_idx::Union{Nothing,Int}
  has_been_updated::Bool
end

function stop_checker(timed_solution)::Bool
  println("Stop Checker")
  return timed_solution.value[2] == optimal_program
end

# initializes entries as undefined BankEntries, they are assigned during execution of the selector and updater functions
function init_bank(problem::Problem, iterator::ProgramIterator)::Tuple{Dict{Int,BankEntry},Int}
  bank = Dict{Int,BankEntry}()
  return (bank, length(get_grammar(iterator.solver).rules))
end

function selector(solution::Tuple{AbstractRuleNode,SynthResult,Dict{Int,AbstractRuleNode},GenericBUState}, bank::Tuple{Dict{Int,BankEntry},Int})
  # Here I will insert elements of the latest results array into the previous one and update the grammar based on that.
  # The bank is updated based on the result of the synth_fn. Only the programs are updates, not the corresponding grammar rules
  found_programs = solution[3]
  bank_entries = bank[1]
  println("Before selection:", bank_entries)
  for idx in eachindex(found_programs)
    if haskey(bank_entries, idx)
      # edit already remembered subprogram
      if !isnothing(found_programs[idx]) && haskey(found_programs, idx) && length(found_programs[idx]) < length(bank_entries[idx].remembered_program)
        bank_entries[idx].remembered_program = found_programs[idx]
        bank_entries[idx].has_been_updated = true
      end
    elseif haskey(found_programs, idx)
      # Add new subprogram to the remembered_subprograms bank
      bank_entries[idx] = BankEntry(found_programs[idx], nothing, false)
    end
  end
  println("After selection", bank_entries)
  # results[end] = curr_result
  return solution
  # This should also work for the removal of elements from the grammar
end

function updater(selected::Tuple{RuleNode,SynthResult,Dict{Int,AbstractRuleNode},GenericBUState}, iterator::ProgramIterator, bank::Tuple{Dict{Int,BankEntry},Int})
  # The latest array in results will contain the simplest subprograms array that matches the latest run.
  iter_grammar = get_grammar(iterator.solver)
  bank_entries = bank[1]

  for idx in eachindex(bank_entries)
    if !haskey(bank_entries, idx)
      continue
    end
    if bank_entries[idx].has_been_updated
      # updates the rule stored at the index (since a simpler program has been found)
      updated_rule = rulenode2expr(bank_entries[idx].remembered_program, iter_grammar)
      iter_grammar.rules[bank_entries[idx].grammar_rule_idx] = updated_rule
      bank_entries[idx].has_been_updated = false
    elseif isnothing(bank_entries[idx].grammar_rule_idx)
      # add a grammar rule and store the index
      add_rule!(iter_grammar, bank_entries[idx].remembered_program)
      bank_entries[idx].grammar_rule_idx = length(iter_grammar.rules)
    end
  end

  # cite this
  IterType = typeof(iterator)
  if IterType <: CostBasedBottomUpIterator
    updated_costs = get_costs(iter_grammar)
    num_rules = length(iter_grammar.rules)
    old_length = length(updated_costs)
    if old_length < num_rules
      resize!(updated_costs, num_rules)
      for i in (old_length+1):num_rules
        updated_costs[i] = 1.0
      end
    end

    old_bank = get_bank(iterator)
    # for type in get_types(old_bank)                                                                                                              
    #     for measure in get_measures(old_bank, type)                                                                                                       
    #         for entry in get_entries(old_bank, type, measure)                                                                                                 
    #             entry.is_new = true                                                                                                                  
    #         end                                                                                                                                      
    #     end                                                                                                                                          
    # end

    new_iterator = IterType(
      iter_grammar,
      get_starting_symbol(iterator.solver);
      bank=old_bank,
      state=selected[4],
      max_depth=iterator.solver.max_depth,
      max_cost=iterator.max_cost,
      current_costs=updated_costs
    )
  else
    new_iterator = IterType(
      iter_grammar,
      get_starting_symbol(iterator.solver),
      max_depth=iterator.solver.max_depth,
      max_size=iterator.solver.max_size
    )
  end

  return new_iterator
end

"""
Iterates over and evaluates programs, mining fragments of those that passed
a subset of tests. 
"""
function synth_fn(
  problem::Problem, iterator::ProgramIterator, interpret::Union{Function,Nothing}, max_enumerations::Int64, tags::Any, mod::Module=Main)::Union{Tuple{AbstractRuleNode,SynthResult,Dict{Int,AbstractRuleNode},GenericBUState},Nothing}

  start_time = time()
  grammar = get_grammar(iterator.solver)
  symboltable::SymbolTable = grammar2symboltable(grammar, mod)

  best_score = 0
  best_program = nothing
  num_iterations = 0

  #fragments = Set{AbstractRuleNode}()
  simplest_subprograms = Dict{Int,AbstractRuleNode}()
  last_state = nothing
  # println("iterator length", length(enumerate(iterator)))
  iteration = iterate(iterator)
  while iteration != nothing
    # println("PING")
    (candidate_program, state) = iteration
    last_state = state
    if (!isnothing(interpret))
      # Don't want to short-circuit since subset of passed examples is useful
      passed_examples = evaluate_with_interpreter(problem, candidate_program, interpret, tags, shortcircuit=false, allow_evaluation_errors=true)
    else
      expr = rulenode2expr(candidate_program, grammar)

      # Don't want to short-circuit since subset of passed examples is useful
      passed_examples = evaluate(problem, expr, symboltable, shortcircuit=false, allow_evaluation_errors=true)
    end
    num_iterations += 1
    idx = bitvec_to_idx(passed_examples)
    if !haskey(simplest_subprograms, idx)
      simplest_subprograms[idx] = freeze_state(candidate_program)
    elseif haskey(simplest_subprograms, idx)
      if length(candidate_program) < length(simplest_subprograms[idx])
        simplest_subprograms[idx] = freeze_state(candidate_program)
      end
    end
    score = count(passed_examples) / length(passed_examples)
    if score > 0.0
      println("Finished evaluating iteration: ", num_iterations)
      println("Program: ", rulenode2expr(candidate_program, grammar))
      println("Score: ", score)
    end
    # if score > 0
    #   fragments_of_program = mine_fragments(freeze_state(candidate_program))
    #   union!(fragments, fragments_of_program)
    # end

    if score == 1
      candidate_program = freeze_state(candidate_program)
      println("Found optimal solution at iteration: ", num_iterations)
      return (candidate_program, optimal_program, simplest_subprograms, state)
    elseif score >= best_score
      best_score = score
      candidate_program = freeze_state(candidate_program)
      best_program = candidate_program
    end

    # Check stopping criteria (get from iterator if available)
    max_time = typemax(Int)  # No time limit for now
    if num_iterations > max_enumerations || time() - start_time > max_time
      println("Max enumerations or time limit exceeded!")
      println("i = ", num_iterations)

      break
    end
    # if (num_iterations % 10 == 0)
    #   println("Finished evaluating iteration: ", num_iterations)
    # end
    iteration = iterate(iterator, state)
  end
  println("Synth finished with num_iterations: ", num_iterations)
  # The enumeration exhausted, but an optimal problem was not found
  return (best_program, suboptimal_program, simplest_subprograms, last_state)
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
      # break
    end
  end

  return passed_examples
end


"""
Returns a BitVector of the examples that were fulfilled
"""
function evaluate_with_interpreter(problem::Problem, rulenode::RuleNode, interpret::Function, tags; shortcircuit::Bool=true, allow_evaluation_errors::Bool=false)::BitVector
  passed_examples = falses(length(problem.spec))

  crashed = false
  # println("PROBLEM SPEC LENGTH: ", length(problem.spec))
  for (i, example) ∈ enumerate(problem.spec)
    try
      output = interpret(rulenode, tags, example.in)
      if (output == example.out)
        passed_examples[i] = true
      elseif (shortcircuit)
        break
      end
    catch e
      # println("evaluation error: ", e)
      # You could also decide to handle less severe errors (such as index out of range) differently,
      # for example by just increasing the error value and keeping the program as a candidate.
      # crashed = true
      # # Throw the error again if evaluation errors aren't allowed
      # eval_error = EvaluationError(rulenode, example.in, e)
      # allow_evaluation_errors || throw(eval_error)
      # break
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
