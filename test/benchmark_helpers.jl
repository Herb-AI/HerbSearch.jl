# Function added from levenstein library: [https://github.com/rawrgrr/Levenshtein.jl/blob/master/src/Levenshtein.jl]
function levenshtein!(
    source::AbstractString,
    target::AbstractString,
    deletion_cost::R,
    insertion_cost::S,
    substitution_cost::T,
    costs::Matrix=Array{promote_type(R, S, T)}(undef, 2, length(target) + 1)
) where {R<:Real,S<:Real,T<:Real}
    cost_type = promote_type(R, S, T)
    if length(source) < length(target)
        # Space complexity of function = O(length(target))
        return levenshtein!(target, source, insertion_cost, deletion_cost, substitution_cost, costs)
    else
        if length(target) == 0
            return length(source) * deletion_cost
        else
            old_cost_index = 1
            new_cost_index = 2

            costs[old_cost_index, 1] = 0
            for i in 1:length(target)
                costs[old_cost_index, i+1] = i * insertion_cost
            end

            i = 0
            for r in source
                i += 1

                # Delete i characters from source to get empty target
                costs[new_cost_index, 1] = i * deletion_cost

                j = 0
                for c in target
                    j += 1

                    deletion = costs[old_cost_index, j+1] + deletion_cost
                    insertion = costs[new_cost_index, j] + insertion_cost
                    substitution = costs[old_cost_index, j]
                    if r != c
                        substitution += substitution_cost
                    end

                    costs[new_cost_index, j+1] = min(deletion, insertion, substitution)
                end

                old_cost_index, new_cost_index = new_cost_index, old_cost_index
            end

            new_cost_index = old_cost_index
            return costs[new_cost_index, length(target)+1]
        end
    end
end

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
function is_test_passed_and_debug(test_res::Union{Tuple{RuleNode,Any},Nothing}, grammar::AbstractGrammar,
    optimal_score::Any, start_time::DateTime, end_time::DateTime=Dates.now())::Bool
    if !isnothing(test_res)
        solution, score = test_res
        passed = score <= optimal_score
        if passed
            print_time_test_end(start_time, end_time=end_time)
        else
            println("Suboptimal program")
            print_time_test_end(start_time, end_time=end_time,
                test_passed=false)
        end
        println(rulenode2expr(solution, grammar))
        return passed
    else
        print_time_test_end(start_time, end_time=end_time,
            test_passed=false)
        return false
    end
end