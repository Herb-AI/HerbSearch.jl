module dev

using Herb
using Revise

using HerbConstraints
using HerbGrammar
using HerbSearch
using HerbInterpret


#=
Helper function that avoids Vector typing errors
=#
execute_test(
    name::String,
    grammar::ContextSensitiveGrammar,
    constraints::Vector,
    examples::Vector,
    expected_size::Int,
    tests::Vector
)::Bool = _execute_test(name, grammar, Vector{Constraint}(constraints), Vector{Example}(examples), expected_size, Vector{Example}(tests))


#=
Executes a test
=#
function _execute_test(
        name::String,
        grammar::ContextSensitiveGrammar,
        constraints::Vector{Constraint},
        examples::Vector{Example},
        expected_size::Int,
        tests::Vector{Example}
    )::Bool
    

    # add all constraints to the grammar
    clearconstraints!(grammar)
    for constraint ∈ constraints
        addconstraint!(grammar, constraint)
    end

    # construct problem
    problem = Problem(examples, "")

    # search the optimal program
    res::Union{Tuple{RuleNode, Any}, Nothing} = search_rulenode(grammar, problem, :Element)
    if isnothing(res)
        printstyled("Test $(name) failed; no solution found\n"; color = :red)
        return false
    end

    # deconstruct the result in a RuleNode and a Julia expression
    (res_rulenode::RuleNode, res_expr::Any) = res

    # determines the size of a Julia expression
    expr_size(ex::Expr) = sum(expr_size(arg) for arg ∈ ex.args)
    expr_size(::Any) = 1

    # check if the size is the same
    actual_size::Int = expr_size(res_expr)
    if actual_size ≠ expected_size
        printstyled("Test $(name) failed; expected size $(expected_size), actual size $(actual_size) (expression = $(res_expr))\n"; color = :red)
        return false
    end

    # check if all constraints are satisfied
    constraints_check_tree::Vector{Bool} = [check_tree(constraint, grammar, res_rulenode) for constraint ∈ constraints]
    if !all(constraints_check_tree)
        failed_constraints::Vector{Int} = lookup(isequal(false), constraints_check_tree)
        printstyled("Test $(name) failed; constraints $(failed_constraints) failed (expression = $(res_expr))", color = :red)
    end

    # check if all additional tests succeed
    symbol_table:: SymbolTable = SymbolTable(grammar)
    tests_succeed::Vector{Bool} = [test.out == test_with_input(symbol_table, res_expr, test.in) for test ∈ tests]
    if !all(tests_succeed)
        failed_tests::Vector{Int} = lookup(isequal(false), tests_succeed)
        printstyled("Test $(name) failed; additional tests $(failed_tests) failed (expression = $(res_expr))", color = :red)
    end

    printstyled("Test $(name) passed (expression = $(res_expr))\n"; color = :green)
    return true
end



#=
Small domains, small operators
Expects to return a program equivalent to 1 + (1 - x)
                                          = 2 - x
=#
begin
    grammar = Herb.HerbGrammar.@csgrammar begin
        Element = |(1 : 3)          # 1 - 3
        Element = Element + Element # 4
        Element = 1 - Element       # 5
        Element = x                 # 6
    end

    constraints = [
        ComesAfter(6, [5])
    ]

    examples = [
        IOExample(Dict(:x => 0), 2),
        IOExample(Dict(:x => 1), 1),
        IOExample(Dict(:x => 2), 0)
    ]

    tests = [
        IOExample(Dict(:x => -2), 4)
    ]


    execute_test("small domains, small operators", grammar, constraints, examples, 5, tests)
end


#=
Small domains, large operators
Expects to return a program equivalent to 4 + x * (x + 3 + 3)
                                          = x^2 + 6x + 4
=#
begin
    grammar = Herb.HerbGrammar.@csgrammar begin
        Element = Element + Element + Element # 1
        Element = Element + Element * Element # 2
        Element = x                           # 3
        Element = |(3 : 5)                    # 4
    end

    constraints = [
        # restrict ... + x * x
        Forbidden(
            MatchNode(2, [MatchVar(:x), MatchNode(3), MatchNode(3)])
        ),

        # restrict 4 and 5 in lower level
        ForbiddenPath(
            [2, 1, 5]
        ),

        ForbiddenPath(
            [2, 1, 6]
        )
    ]

    examples = [
        IOExample(Dict(:x => 1), 11)
        IOExample(Dict(:x => 2), 20)
        IOExample(Dict(:x => -1), -1)
    ]

    tests = [
        IOExample(Dict(:x => 0), 4)
    ]


    execute_test("small domains, large operators", grammar, constraints, examples, 8, tests)
end


#=
Large domains, small operators
Expects to return a program equivalent to (1 - (((1 - x) - 1) - 1)) - 1
                                          = x + 1
=#
begin
    grammar = Herb.HerbGrammar.@csgrammar begin
        Element = |(1 : 20)   # 1 - 20
        Element = Element - 1 # 21
        Element = 1 - Element # 22
        Element = x           # 23
    end

    constraints = [
        OrderedPath([21, 22, 23])
    ]

    examples = [
        IOExample(Dict(:x => 1), 2)
        IOExample(Dict(:x => 10), 11)
    ]

    tests = [
        IOExample(Dict(:x => 0), 1)
        IOExample(Dict(:x => 100), 101)
    ]


    execute_test("large domains, small operators", grammar, constraints, examples, 11, tests)
end


#=
Large domains, large operators
Expects to return a program equivalent to 18 + 4x
=#
begin
    grammar = Herb.HerbGrammar.@csgrammar begin
        Element = |(0 : 20)                   # 1 - 20
        Element = Element + Element + Element # 21
        Element = Element + Element * Element # 22
        Element = x                           # 23
    end

    constraints = [
        # enforce ordering on + +
        Ordered(
            MatchNode(21, [MatchVar(:x), MatchVar(:y), MatchVar(:z)]),
            [:x, :y, :z]
        )
    ]

    examples = [
        IOExample(Dict(:x => 1), 22),
        IOExample(Dict(:x => 0), 18),
        IOExample(Dict(:x => -1), 14)
    ]

    tests = [
        IOExample(Dict(:x => 100), 418),
    ]


    execute_test("large domains, large operators", grammar, constraints, examples, 5, tests)
end


#=
Large grammar with if-statements
Expects to return a program equivalent to (x == 2) ? 1 : (x + 2)
=#
begin
    grammar = Herb.HerbGrammar.@csgrammar begin
        Element = Number # 1
        Element = Bool # 2
    
        Number = |(1 : 3) # 3-5
        
        Number = Number + Number # 6
        Bool = Number ≡ Number # 7
        Number = x # 8
        
        Number = Bool ? Number : Number # 9
        Bool = Bool ? Bool : Bool # 10
    end

    constraints = [
        # forbid ? ≡ ?
        Forbidden(
            MatchNode(7, [MatchVar(:x), MatchVar(:x)])
        ),
        
        # order ≡
        Ordered(
            MatchNode(7, [MatchVar(:x), MatchVar(:y)]),
            [:x, :y]
        ),

        # order +
        Ordered(
            MatchNode(6, [MatchVar(:x), MatchVar(:y)]),
            [:x, :y]
        )
    ]

    examples = [
        IOExample(Dict(:x => 0), 2)
        IOExample(Dict(:x => 1), 3)
        IOExample(Dict(:x => 2), 1)
    ]

    tests = [
        IOExample(Dict(:x => 3), 5)
    ]


    execute_test("large grammar with if-statements", grammar, constraints, examples, 7, tests)
end

end
