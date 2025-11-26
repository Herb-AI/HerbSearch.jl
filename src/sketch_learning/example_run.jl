using Pkg
Pkg.activate(".") 

using HerbGrammar, HerbCore, HerbSpecification, HerbSearch

g_1 = @csgrammar begin
    Number = |(1:2)
    Number = x
    Number = Number + Number
    Number = Number * Number
end

problem_1 = Problem([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5])
iterator_1 = BFSIterator(g_1, :Number, max_depth=3)

selection_criteria = 1/5

selector = function(results)
    programs = AbstractRuleNode[]
    for (prog, score) in results[1]
        push!(programs, prog)
    end

    return programs
end

updater = function(selected, iterator)
    grammar = iterator.solver.grammar
    patterns = multi_MST_unify(selected, grammar;
                               min_nonholes=1,
                               max_holes=3)

    for patt in patterns
        rhs = rulenode2expr(patt, grammar)
        lhs_symbol = return_type(grammar, patt)

        rule_expr = :($lhs_symbol = $rhs)
        println("ADDING RULE ", rule_expr)
        add_rule!(iterator.solver.grammar, rule_expr)
    end
    return iterator
end

stop_checker = sol -> begin
    (results, optimal_found) = sol.value
    optimal_found
end

synth_fn= (problem, iterator) -> synth_multi(
        problem,
        iterator;
        selection_criteria=selection_criteria,
        max_enumerations=6
)

ctrl = BudgetedSearchController(
    problem=problem_1,
    iterator=iterator_1,
    synth_fn=synth_fn,
    attempts=5,
    selector=selector,
    updater=updater,
    stop_checker=stop_checker
)

results, times, time_count = run_budget_search(ctrl)





