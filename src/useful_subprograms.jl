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
  BankEntry as IteratorBankEntry, SizeBasedBottomUpIterator

# ID of each bank entry corresponds to a bitvector of passed examples
@kwdef mutable struct BankEntry
  remembered_program::AbstractRuleNode
  grammar_rule_idx::Union{Nothing,Int}
  has_been_updated::Bool
end

function stop_checker(timed_solution)::Bool
  return timed_solution.value[1][2] == optimal_program || timed_solution.value[1][5]
end

# initializes entries as undefined BankEntries, they are assigned during execution of the selector and updater functions
function init_bank(problem::Problem, iterator::ProgramIterator)::Tuple{Dict{Int,BankEntry},Int}
  bank = Dict{Int,BankEntry}()
  return (bank, length(get_grammar(iterator.solver).rules))
end

function selector(solution::Tuple{Union{AbstractRuleNode,Nothing},SynthResult,Dict{Int,AbstractRuleNode},Float64,Bool}, bank::Tuple{Dict{Int,BankEntry},Int})
  # Here I will insert elements of the latest results array into the previous one and update the grammar based on that.
  # The budgeted search bank is updated based on the result of the synth_fn. Only the programs are updates, not the 
  # corresponding grammar rules
  if isnothing(solution[2])
    return solution
  end
  found_programs = solution[3]
  bank_entries = bank[1]
  for idx in eachindex(found_programs)
    if haskey(bank_entries, idx)
      # edit already remembered subprogram if the new one is simpler
      if !isnothing(found_programs[idx]) && haskey(found_programs, idx) && length(found_programs[idx]) < length(bank_entries[idx].remembered_program)
        bank_entries[idx].remembered_program = found_programs[idx]
        bank_entries[idx].has_been_updated = true
      end
    elseif haskey(found_programs, idx)
      # add new subprogram to the remembered_subprograms bank
      bank_entries[idx] = BankEntry(found_programs[idx], nothing, false)
    end
  end
  return solution
end

function updater(selected::Tuple{Union{RuleNode,Nothing},SynthResult,Dict{Int,AbstractRuleNode},Float64,Bool}, iterator::ProgramIterator, bank::Tuple{Dict{Int,BankEntry},Int}, state, data_frame)
  if isnothing(selected[2])
    return iterator
  end
  # latest dict in results will contain the simplest subprograms dict that matches the latest run.
  iter_grammar = get_grammar(iterator.solver)
  bank_entries = bank[1]

  is_cost_based = iterator isa CostBasedBottomUpIterator

  updates = []
  for idx in eachindex(bank_entries)
    if !haskey(bank_entries, idx)
      continue
    end

    # validate that the remembered program has valid rule indices for the current grammar
    program = bank_entries[idx].remembered_program
    try
      # test if the program can be converted to an expression with current grammar
      rulenode2expr(program, iter_grammar)
    catch e
      # program has invalid rule indices for current grammar
      println("WARNING: Cannot convert remembered program to expression")
      println("  RuleNode: ", program)
      println("  Grammar has $(length(iter_grammar.rules)) rules")
      println("  Error: ", e)
      continue
    end

    if bank_entries[idx].has_been_updated
      # a simpler program has been found - rebuild grammar with the replacement
      rule_to_replace = bank_entries[idx].grammar_rule_idx
      new_rule_expr = rulenode2expr(bank_entries[idx].remembered_program, iter_grammar)
      old_rule_expr = iter_grammar.rules[rule_to_replace]
      rule_type = iter_grammar.types[rule_to_replace]

      # Create new grammar by adding all rules in order, substituting the updated one. This was done
      # since initially remove_rule! and add_rule! were used to update the rule, but this resulted in
      # programs generating that were referencing "nothing" rules.
      new_grammar = HerbGrammar.@csgrammar begin end  # Empty grammar
      for i in 1:length(iter_grammar.rules)
        r_type = iter_grammar.types[i]
        if i == rule_to_replace
          # use the new simplified rule
          add_rule!(new_grammar, :($r_type = $new_rule_expr))
        else
          # copy existing rule
          r_expr = iter_grammar.rules[i]
          add_rule!(new_grammar, :($r_type = $r_expr))
        end
      end

      # replace the grammar in the iterator's solver
      iterator.solver.grammar = new_grammar
      iter_grammar = new_grammar

      bank_entries[idx].has_been_updated = false

      # CostBased-specific: update costs and bank
      # Note: the CostBasedBottomUpIterator was not used in the final version of the eperiments, since it was enumerating
      # programs extremely slowly, so this code was not part of the final experiment
      if is_cost_based
        rule_cost = max(state.last_horizon, 1.0)
        push!(iter_grammar.log_probabilities, -rule_cost)
        push!(iterator.current_costs, rule_cost)
        push!(get_entries(get_bank(iterator), return_type(iter_grammar, bank_entries[idx].remembered_program), rule_cost), IteratorBankEntry{RuleNode}(bank_entries[idx].remembered_program, true))
      end

      push!(updates, "Update: " * string(new_rule_expr) * " Replaces: " * string(old_rule_expr))

    elseif isnothing(bank_entries[idx].grammar_rule_idx)
      # add a grammar rule and store the index
      add_rule!(iter_grammar, bank_entries[idx].remembered_program)
      bank_entries[idx].grammar_rule_idx = length(iter_grammar.rules) + 1

      # CostBased-specific: update costs and bank
      if is_cost_based
        rule_cost = max(state.last_horizon, 1.0)
        push!(iter_grammar.log_probabilities, -rule_cost)
        push!(iterator.current_costs, rule_cost)
        push!(get_entries(get_bank(iterator), return_type(iter_grammar, bank_entries[idx].remembered_program), rule_cost), IteratorBankEntry{RuleNode}(bank_entries[idx].remembered_program, true))
      end

      push!(updates, "New Rule: " * string(rulenode2expr(bank_entries[idx].remembered_program, iter_grammar)))
    end
  end

  push!(data_frame, (attempt = nrow(data_frame) + 1, best_program = isnothing(selected[1]) ? "Nothing" : string(rulenode2expr(selected[1], iter_grammar)), program_score = selected[4], time = 0, new_updated_rules = isempty(updates) ? "No updates" : join(updates)))

  # If the grammar was modified and using SizeBasedBottomUpIterator, create a new iterator to avoid BitVector dimension 
  # mismatch errors. This did not seem to be an issue for the CostBasedIterator variant since it seemed that no errors were thrown.
  if !isempty(updates) && iterator isa SizeBasedBottomUpIterator
    new_iterator = SizeBasedBottomUpIterator(
      iter_grammar,
      get_starting_symbol(iterator);
      max_depth=get_max_depth(iterator)
    )
    return new_iterator
  end

  return iterator
end

"""
Iterates over and evaluates programs, mining fragments of those that passed
a subset of tests. 
"""
function synth_fn(
  problem::Problem, iterator::ProgramIterator, interpret::Union{Function,Nothing}, max_enumerations::Int64, tags::Any, mod::Module=Main, state=nothing)::Tuple{Union{Tuple{Union{AbstractRuleNode,Nothing},SynthResult,Dict{Int,AbstractRuleNode},Float64,Bool},Nothing},Union{GenericBUState,Nothing}}

  start_time = time()
  grammar = get_grammar(iterator.solver)
  num_grammar_rules = length(grammar.rules)

  best_score = -1
  best_program = nothing
  num_iterations = 0

  simplest_subprograms = Dict{Int,AbstractRuleNode}()
  last_state = state

  # check if the state is incompatible with the current grammar (e.g., grammar was modified)
  # if so, reset state to avoid BitVector dimension mismatch errors
  if !isnothing(last_state) && hasproperty(last_state, :starting_node)
    starting_node = last_state.starting_node
    if hasproperty(starting_node, :domain) && length(starting_node.domain) != num_grammar_rules
      # grammar size changed, reset state to start fresh with new grammar
      last_state = nothing
    end
  end

  iteration = nothing
  if !isnothing(last_state)
    iteration = iterate(iterator, last_state)
  else
    iteration = iterate(iterator)
  end
  while !isnothing(iteration)
    (candidate_program, state) = iteration
    candidate_program = freeze_state(candidate_program)
    last_state = state
    if (!isnothing(interpret))
      # don't want to short-circuit since subset of passed examples is useful
      passed_examples = evaluate_with_interpreter(problem, candidate_program, interpret, tags, shortcircuit=false, allow_evaluation_errors=true)
    else
      symboltable::SymbolTable = grammar2symboltable(grammar, mod)
      expr = rulenode2expr(candidate_program, grammar)

      # don't want to short-circuit since subset of passed examples is useful
      passed_examples = evaluate(problem, expr, symboltable, shortcircuit=false, allow_evaluation_errors=true)
    end
    num_iterations += 1
    idx = bitvec_to_idx(passed_examples)
    # this check was added to avoid remembering subprograms if they passed an empty subset of tests (so score = 0)
    if idx > 1
      if !haskey(simplest_subprograms, idx)
        simplest_subprograms[idx] = candidate_program
      elseif haskey(simplest_subprograms, idx)
        if length(candidate_program) < length(simplest_subprograms[idx])
          simplest_subprograms[idx] = candidate_program
        end
      end
    end
    score = count(passed_examples) / length(passed_examples)

    if score > best_score
      best_score = score
      best_program = candidate_program
    end

    if score == 1
      # println("Found optimal solution at iteration: ", num_iterations)
      return ((best_program, optimal_program, simplest_subprograms, best_score, true), last_state)
    end
    # check stopping criteria (get from iterator if available)
    max_time = typemax(Int)  # No time limit for now
    if num_iterations >= max_enumerations

      break
    end
    iteration = iterate(iterator, state)
  end
  # the enumeration exhausted, but an optimal problem was not found
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
      # you could also decide to handle less severe errors (such as index out of range) differently,
      # for example by just increasing the error value and keeping the program as a candidate
      crashed = true
      # throw the error again if evaluation errors aren't allowed
      eval_error = EvaluationError(expr, example.in, e)
      allow_evaluation_errors || throw(eval_error)
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

function bitvec_to_idx(bv::BitVector)::Int64
  sum = 1
  for pos in eachindex(bv)
    sum += bv[pos] * 2^(pos - 1)
  end
  return sum
end

end
