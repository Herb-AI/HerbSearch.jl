module UsefulSubprograms

export UsefulSubprograms

using HerbGrammar
using HerbCore
using HerbInterpret
using HerbSpecification
using HerbConstraints
using CSV
using DataFrames

import ..HerbSearch: optimal_program, suboptimal_program, SynthResult, ProgramIterator,
  get_grammar, get_max_size, EvaluationError, BFSIterator, get_starting_symbol,
  BudgetedSearchController, CostBasedBottomUpIterator, get_costs, get_bank,
  inner_bank, get_entries, get_types, get_measures, GenericBUState,
  BankEntry as IteratorBankEntry

# Id of each bank entry corresponds to a bitvector of passed examples
@kwdef mutable struct BankEntry
  remembered_program::AbstractRuleNode
  grammar_rule_idx::Union{Nothing,Int}
  has_been_updated::Bool
end

function stop_checker(timed_solution)::Bool
  println("Stop Checker")
  return timed_solution.value[1][2] == optimal_program || timed_solution.value[1][5]
end

# initializes entries as undefined BankEntries, they are assigned during execution of the selector and updater functions
function init_bank(problem::Problem, iterator::ProgramIterator)::Tuple{Dict{Int,BankEntry},Int}
  bank = Dict{Int,BankEntry}()
  return (bank, length(get_grammar(iterator.solver).rules))
end

function selector(solution::Tuple{Union{AbstractRuleNode,Nothing},SynthResult,Dict{Int,AbstractRuleNode},Float64,Bool}, bank::Tuple{Dict{Int,BankEntry},Int})
  # Here I will insert elements of the latest results array into the previous one and update the grammar based on that.
  # The bank is updated based on the result of the synth_fn. Only the programs are updates, not the corresponding grammar rules
  if isnothing(solution[2])
    return solution
  end
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
      # add new subprogram to the remembered_subprograms bank
      bank_entries[idx] = BankEntry(found_programs[idx], nothing, false)
    end
  end
  println("After selection", bank_entries)
  # results[end] = curr_result
  return solution
  # This should also work for the removal of elements from the grammar
end

function updater(selected::Tuple{Union{RuleNode,Nothing},SynthResult,Dict{Int,AbstractRuleNode},Float64,Bool}, iterator::ProgramIterator, bank::Tuple{Dict{Int,BankEntry},Int}, state::GenericBUState, data_frame)
  if isnothing(selected[2])
    return solution
  end
  #latest array in results will contain the simplest subprograms array that matches the latest run.
  iter_grammar = get_grammar(iterator.solver)
  bank_entries = bank[1]

  updates = []
  for idx in eachindex(bank_entries)
    if !haskey(bank_entries, idx)
      continue
    end
    if bank_entries[idx].has_been_updated
      #prob will error cuz rulenode2expr returns a string
      println("Updating Rule")
      # updates the rule stored at the index (since a simpler program has been found)
      remove_rule!(iter_grammar, bank_entries[idx].grammar_rule_idx)
      add_rule!(iter_grammar, bank_entries[idx].remembered_program)
      bank_entries[idx].has_been_updated = false

      rule_cost = max(state.last_horizon, 1.0)
      push!(iter_grammar.log_probabilities, -rule_cost)
      push!(iterator.current_costs, rule_cost)
      push!(get_entries(get_bank(iterator), return_type(iter_grammar, bank_entries[idx].remembered_program), rule_cost), IteratorBankEntry{RuleNode}(bank_entries[idx].remembered_program, true))
      push!(updates, "Update: " * string(rulenode2expr(bank_entries[idx].remembered_program, iter_grammar)) * " Replaces: ")
      bank_entries[idx].grammar_rule_idx = length(iter_grammar.rules) + 1
    elseif isnothing(bank_entries[idx].grammar_rule_idx)
      # add a grammar rule and store the index
      add_rule!(iter_grammar, bank_entries[idx].remembered_program)
      bank_entries[idx].grammar_rule_idx = length(iter_grammar.rules) + 1

      rule_cost = max(state.last_horizon, 1.0)
      push!(iter_grammar.log_probabilities, -rule_cost)
      push!(iterator.current_costs, rule_cost)
      push!(get_entries(get_bank(iterator), return_type(iter_grammar, bank_entries[idx].remembered_program), rule_cost), IteratorBankEntry{RuleNode}(bank_entries[idx].remembered_program, true))
      push!(updates, "New Rule: " * string(rulenode2expr(bank_entries[idx].remembered_program, iter_grammar)))
    end
  end

  push!(data_frame, (attempt = nrow(data_frame) + 1, best_program = isnothing(selected[1]) ? "Nothing" : string(rulenode2expr(selected[1], iter_grammar)), program_score = selected[4], time = 0, new_updated_rules = isempty(updates) ? "No updates" : join(updates)))

  # add info to the data frame

  # cite this
  # IterType = typeof(iterator)
  # if IterType <: CostBasedBottomUpIterator
    # updated_costs = get_costs(iter_grammar)
    # num_rules = length(iter_grammar.rules)
    # old_length = length(updated_costs)
    # if old_length < num_rules
    #   resize!(updated_costs, num_rules)
    #   for i in (old_length+1):num_rules
    #     updated_costs[i] = 1.0
    #   end
    # end

    # iterator.grammar = iter_grammar
    # iterator.current_costs = new_costs
    # old_bank = get_bank(iterator)
    # for type in get_types(old_bank)                                                                                                              
    #     for measure in get_measures(old_bank, type)                                                                                                       
    #         for entry in get_entries(old_bank, type, measure)                                                                                                 
    #             entry.is_new = true                                                                                                                  
    #         end                                                                                                                                      
    #     end                                                                                                                                          
    # end

    # new_iterator = IterType(
    #   iter_grammar,
    #   get_starting_symbol(iterator.solver);
    #   bank=old_bank,
    #   state=selected[4],
    #   max_depth=iterator.solver.max_depth,
    #   max_cost=iterator.max_cost,
    #   current_costs=updated_costs
    # )
    return iterator
  # else
  #   new_iterator = IterType(
  #     iter_grammar,
  #     get_starting_symbol(iterator.solver),
  #     max_depth=iterator.solver.max_depth,
  #     max_size=iterator.solver.max_size
  #   )
  # end

  # return new_iterator
end

"""
Iterates over and evaluates programs, mining fragments of those that passed
a subset of tests. 
"""
function synth_fn(
  problem::Problem, iterator::ProgramIterator, interpret::Union{Function,Nothing}, max_enumerations::Int64, tags::Any, mod::Module=Main, state=nothing)::Tuple{Union{Tuple{Union{AbstractRuleNode,Nothing},SynthResult,Dict{Int,AbstractRuleNode},Float64,Bool},Nothing},GenericBUState}

  start_time = time()
  grammar = get_grammar(iterator.solver)

  best_score = -1
  best_program = nothing
  num_iterations = 0

  #fragments = Set{AbstractRuleNode}()
  simplest_subprograms = Dict{Int,AbstractRuleNode}()
  # println("iterator length", length(enumerate(iterator)))
  last_state = state
  iteration = nothing
  if !isnothing(last_state)
    iteration = iterate(iterator, last_state)
  else
    iteration = iterate(iterator)
  end
  while !isnothing(iteration)
    # println("PING")
    (candidate_program, state) = iteration
    last_state = state
    if (!isnothing(interpret))
      # Don't want to short-circuit since subset of passed examples is useful
      passed_examples = evaluate_with_interpreter(problem, candidate_program, interpret, tags, shortcircuit=false, allow_evaluation_errors=true)
    else
      symboltable::SymbolTable = grammar2symboltable(grammar, mod)
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
    # if score > 0.0
    #   println("Finished evaluating iteration: ", num_iterations)
    #   println("Program: ", rulenode2expr(candidate_program, grammar))
    #   println("Score: ", score)
    # end
    # if score > 0
    #   fragments_of_program = mine_fragments(freeze_state(candidate_program))
    #   union!(fragments, fragments_of_program)
    # end

    if score > best_score
      best_score = score
      candidate_program = freeze_state(candidate_program)
      best_program = candidate_program
    end

    if score == 1
      println("Found optimal solution at iteration: ", num_iterations)
      return ((best_program, optimal_program, simplest_subprograms, best_score, true), last_state)
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
  println("Best_program: ", isnothing(best_program) ? "Nothing" : rulenode2expr(best_program, grammar))
  println("Score: ", best_score)
  # The enumeration exhausted, but an optimal problem was not found
  return ((best_program, suboptimal_program, simplest_subprograms, best_score, isnothing(iteration)), last_state)
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
      output = Base.invokelatest(interpret, rulenode, tags, example.in)
      if (output == example.out)
        passed_examples[i] = true
      elseif (shortcircuit)
        break
      end
    catch e
      crashed = true
      break
    end
  end

  # for now assume crashes result in 0 score
  return crashed ? falses(length(problem.spec)) : passed_examples
end

# function evaluate_with_interpreter(problem::Problem, rulenode::RuleNode, interpreter::Function, tags; shortcircuit::Bool=true,                   
#   allow_evaluation_errors::Bool=false)::BitVector                                                                                                  
#     passed_examples = falses(length(problem.spec))                                                                                                 
#
#     # Debug: check what interpreter is                                                                                                             
#     println("interpreter: ", interpreter)                                                                                                          
#     println("interpreter methods: ", methods(interpreter))               
#
#     for (i, example) ∈ enumerate(problem.spec)                           
#       try                           
#         println("Calling with: rulenode=", rulenode, " tags=", typeof(tags), " input=", example.in)                                                
#         output = Base.invokelatest(interpreter, rulenode, tags, example.in)                                                                        
#         println("Output: ", output, " Expected: ", example.out)          
#         if (output == example.out)  
#           passed_examples[i] = true 
#         elseif (shortcircuit)       
#           break                     
#         end                         
#       catch e                       
#         println("ERROR: ", e)       
#         println("Stacktrace: ")     
#         for (exc, bt) in current_exceptions()                            
#           showerror(stdout, exc, bt)
#           println()                 
#         end                         
#         break                       
#       end                           
#     end                             
#
#     return passed_examples          
#   end 

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
