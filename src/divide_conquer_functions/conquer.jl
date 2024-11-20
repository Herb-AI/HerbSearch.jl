
"""
    $(TYPEDSIGNATURES)

Takes in the problems with the found solutions and combines them into a global solution program 
by combining them into a decision tree.
"""
function conquer_combine(problems_to_solutions:: Dict{Problem, Vector{RuleNode}}, grammar::AbstractGrammar, n_predicates::Int, sym_bool::Symbol, sym_start::Symbol)
    # TODO
    # make sure grammar has if-else rulenode
    return_type = grammar.rules[grammar.bytype[sym_start][1]] # return type of the starting symbol in the grammar
    idx_ifelse = findfirst(r -> r == :($sym_bool ? $return_type : $return_type), grammar.rules)
    if isnothing(idx_ifelse)
        throw(DecisionTreeError("Conditional if-else statement not found"))
    end
    # TODO: !!!!!!! Turn dict into vectors
    # vec_problems_solutions = Vector{Tuple{RuleNode, Vector{RuleNode}}}
    vec_problems_solutions = [(prob, sol[1]) for (prob, sol) in problems_to_solutions ]
    # TODO: labels: problem-solution-map ("terms"?)
    # predicates: new BFSIterator over grammar, start symbol Bool
    predicates = get_predicates(grammar, sym_bool, n_predicates)
    # Use predicates and sub-problems to get features.
    # TODO: features: Feature vectors are created by evaluating an input from the IO examples on predicate expressions.
    # Take labls and features to make DecisionTree
    # See decision tree example: https://github.com/Herb-AI/HerbSearch.jl/blob/subset-search/src/subset_iterator.jl
    # TODO: better docs
end


function get_predicates( grammar::AbstractGrammar,
    sym_bool::Symbol,
    n_predicates::Number,
)::Vector{RuleNode}

    iterator = BFSIterator(grammar, sym_bool)
    predicates = Vector{RuleNode}()
    # TODO: how to exclude trivial predicates?  
    # arg_rules = Vector{Int64}()
    # for (i, rule) in enumerate(grammar.rules)
    #     if typeof(rule) == Symbol && occursin("_arg_", String(rule))
    #         push!(arg_rules, i)
    #     end            
    # end
    for (i, candidate_program) ∈ enumerate(iterator)
        candidate_program = freeze_state(candidate_program) # TODO: why freeze_state?
        push!(predicates, candidate_program) 
        # TODO: ?? add predicate only if contains rule with an argument
        # # if the intersection of arg_rules and rules in candidate_program is >= 1
        # if length(intersect(arg_rules, collect_rules_from_rulenode(candidate_program))) >= 1
        #     push!(predicates, candidate_program)
        # end
        if i >= n_predicates
            break
        end
    end
    return predicates
end

"""
    Returns a matrix containing the feature vectors for all problem/predicate combinations. A feature vector is obtained by evaluating
    a problem from the `problems_to_solutions` map on a predicate.
"""
function get_features(problems_to_solutions:: Dict{Problem, Vector{RuleNode}}, predicates::Vector{RuleNode})
    features = trues(length(problems_to_solutions), length(predicates))
    
    for (i, e) in enumerate(examples) # TODO: make this work on map
        feature_vec = Vector()
        for p in predicates
            expr = rulenode2expr(p, grammar)
    #         try
    #             o = execute_on_input(symboltable, expr, e.in)
    #             push!(feature_vec, o)
    #         catch err
    #             # Throw the error again if evaluation errors aren't allowed
    #             eval_error = EvaluationError(expr, e.in, err)
    #             allow_evaluation_errors || throw(eval_error)
    #             push!(outputs, false)
    #             # break
    #         end
            
        end
    #     features[i, :] = feature_vec
    end
    return features
end

function get_labels(problems_to_solutions:: Dict{Problem, Vector{RuleNode}})::Vector{String}
    # TODO: Does Vector{String} make sense as return type? 
    # Use first solution as label for a problem
    labels = [string(solutions[1]) for (problem, solutions) in problems_to_solutions]
    return labels


end

# Questions:
# What assumptions do we want to make?
# - Can we use _arg_ to discard trivial predicates?
# - If-else in e.g. robot benchmarks would not detected