using Dates

"""
    Prints test message (name) and returns the start time
"""
function print_time_test_start(message::AbstractString; print_separating_dashes=true)::DateTime
    if print_separating_dashes
        println()
        println("--------------------------------------------------")
    end
    printstyled(message * "\n"; color=:blue)
    if print_separating_dashes
        println("--------------------------------------------------")
    end
    return Dates.now()
end

"""
    Prints and returns the duration of the test
"""
function print_time_test_end(start_time::DateTime; end_time::DateTime=Dates.now(), test_passed=true)::DateTime
    duration = max(end_time - start_time, Dates.Millisecond(0))
    println()
    if test_passed
        printstyled("Pass. Duration: "; color=:green)
    else
        printstyled("Fail. Duration: "; color=:red)
    end
    println("$(duration)")
    return duration
end

"""
    Prints debugging information and returns whether the test passed
"""
function is_test_passed_and_debug(test_res::SearchStats, grammar::AbstractGrammar,
    optimal_score::Any, start_time::DateTime, end_time::DateTime=Dates.now())::Bool
    if !isnothing(test_res)
        passed = test_res.score <= optimal_score && !isa(test_res.program, Nothing)
        if passed
            print_time_test_end(start_time, end_time=end_time)
        else
            println("Suboptimal program")
            print_time_test_end(start_time, end_time=end_time, test_passed=false)
        end
        if !isa(test_res.program, Nothing)
            println(rulenode2expr(test_res.program, grammar))
        end
        return passed
    else
        print_time_test_end(start_time, end_time=end_time, test_passed=false)
        return false
    end
end

function run_benchmark(title::AbstractString, init_grammar::AbstractGrammar, problems::Vector{Problem},
    identifiers::Vector{String}, aux::AuxFunction, rule_symbol::Symbol, interpret::Function;
    max_depth::Int, max_iterations::Int, max_enumerations::Int, allow_evaluation_errors=false)
    total_start_time = print_time_test_start(title)

    regular_passed_tests = 0
    aulile_passed_tests = 0
    for (i, problem) in enumerate(problems)
        grammar = deepcopy(init_grammar)
        id = get(identifiers, i, "?")
        print_time_test_start("Problem $i (id = $id)", print_separating_dashes=false)

        regular_synth_start_time = print_time_test_start("\n\tRegular Synth Results:\n",
            print_separating_dashes=false)
        regular_synth_result = synth_with_aux(problem, BFSIterator(grammar, :Start, max_depth=max_depth),
            grammar, default_aux, Dict{Int,AbstractRuleNode}(), typemax(Int), interpret=interpret,
            allow_evaluation_errors=allow_evaluation_errors, max_enumerations=max_enumerations)

        if is_test_passed_and_debug(regular_synth_result, grammar, 0, regular_synth_start_time)
            regular_passed_tests += 1
        end

        aulile_start_time = print_time_test_start("\n\tAulile Results:\n", print_separating_dashes=false)
        aulile_result = aulile(problem, BFSIterator, grammar, :Start, rule_symbol, aux, interpret=interpret,
            allow_evaluation_errors=allow_evaluation_errors,
            max_iterations=max_iterations, max_depth=max_depth,
            max_enumerations=(max_enumerations / max_iterations))

        if is_test_passed_and_debug(aulile_result, grammar, aux.best_value, aulile_start_time)
            aulile_passed_tests += 1
        end

        println("------------------------")
    end

    println()
    println("Without Aulile Passed: $(regular_passed_tests)/$(length(problems)) tests.")
    println("With Aulile Passed: $(aulile_passed_tests)/$(length(problems)) tests.")
    print_time_test_end(total_start_time, test_passed=(aulile_passed_tests == length(problems)))
end
