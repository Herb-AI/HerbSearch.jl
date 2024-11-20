
@testset verbose=true "Search procedure synth" begin
    g₁ = @csgrammar begin
        Number = |(1:2)
        Number = x
        Number = Number + Number
        Number = Number * Number
    end

    @testset "Search" begin
        problem = Problem([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5])
        iterator = BFSIterator(g₁, :Number, max_depth=5)

        solution, flag = synth(problem, iterator)
        program = rulenode2expr(solution, g₁)

        @test execute_on_input(SymbolTable(g₁), program, Dict(:x => 6)) == 2*6+1
    end

    @testset "Search max_enumerations stopping condition" begin
        problem = Problem([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5])

        iterator = BFSIterator(g₁, :Number)
        solution, flag = synth(problem, iterator, max_enumerations=5)

        @test flag == suboptimal_program
    end

    @testset "Search with errors in evaluation" begin
        g₂ = @csgrammar begin
            Number = 1
            List = []
            Index = List[Number]
        end
        
        problem = Problem([IOExample(Dict(), x) for x ∈ 1:5])
        iterator = BFSIterator(g₂, :Index, max_depth=2)
        solution, flag = synth(problem, iterator, allow_evaluation_errors=true)

        @test flag == suboptimal_program
    end

    @testset "Best search" begin
        problem = Problem(push!([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5], IOExample(Dict(:x => 5), 15)))
        iterator = BFSIterator(g₁, :Number, max_depth=3)

        solution, flag = synth(problem, iterator)
        program = rulenode2expr(solution, g₁)

        @test flag == suboptimal_program
        @test execute_on_input(SymbolTable(g₁), program, Dict(:x => 6)) == 2*6+1

    end

    @testset "Search_best max_enumerations stopping condition" begin
        problem = Problem([IOExample(Dict(:x => x), 2x-1) for x ∈ 1:5])
        iterator = BFSIterator(g₁, :Number)

        solution, flag = synth(problem, iterator, max_enumerations=3)
        program = rulenode2expr(solution, g₁)


        #@test program == :x #the new BFSIterator returns program == 1, which is also valid
        @test flag == suboptimal_program
    end

    @testset "Search_best with errors in evaluation" begin
        g₃ = @csgrammar begin
            Number = 1
            List = []
            Index = List[Number]
        end
        
        problem = Problem([IOExample(Dict(), x) for x ∈ 1:5])
        iterator = BFSIterator(g₃, :Index, max_depth=2)
        solution, flag = synth(problem, iterator, allow_evaluation_errors=true) 

        @test solution == RuleNode(3, [RuleNode(2), RuleNode(1)])
        @test flag == suboptimal_program
    end
end

@testset verbose=true "Search procedure divide and conquer" begin
    @test 1 == 2 # failing test is just a reminder to add actually useful tests.

    @testset verbose =true "divide, stopping criteria" begin
        problem = Problem([IOExample(Dict(), x) for x ∈ 1:3])
        expected_subproblems = [Problem([IOExample(Dict(), 1)]), Problem([IOExample(Dict(), 2)]), Problem([IOExample(Dict(), 3)])]
        subproblems = divide_by_example(problem) 
        # TODO: test equality

        # Stopping criteria: stop search once we have a solution to each subproblem
        problems_to_solutions::Dict{Problem, Vector{RuleNode}} = Dict(p => [] for p in subproblems)

        push!(problems_to_solutions[subproblems[1]], RuleNode(3))
        @test all(!isempty, values(problems_to_solutions)) == false

        push!(problems_to_solutions[subproblems[1]], RuleNode(4))
        push!(problems_to_solutions[subproblems[2]], RuleNode(3))
        @test all(!isempty, values(problems_to_solutions)) == false

        push!(problems_to_solutions[subproblems[3]], RuleNode(3))
        @test all(!isempty, values(problems_to_solutions)) == true
    end

    @testset verbose =true "decide" begin
        grammar = @csgrammar begin
            Number = |(1:2)
            Number = x
            Number = Number + Number
            Number = Number * Number
        end
        symboltable = SymbolTable(grammar)
        problem1 = Problem([IOExample(Dict(:x => 1), 3)])
        problem2 = Problem([IOExample(Dict(:x => 1), 4)])
        program = RuleNode(4, [RuleNode(3), RuleNode(2)])
        expr = rulenode2expr(program, grammar)
        @test decide_if_solution(problem1, program, expr, symboltable) == true
        @test decide_if_solution(problem2, program, expr, symboltable) == false 
    end

    @testset verbose =true "conquer" begin
        grammar = @csgrammar begin
            Start = Integer
            Integer = Condition ? Integer : Integer
            Integer = 0
            Integer = 1
            Input = _arg_1 
            Input = _arg_2
            Integer = Input
            Integer = Integer + Integer
            Condition = Integer <= Integer
            Condition = Condition && Condition  
            Condition = !Condition
        end

        subproblems = [Problem([IOExample(Dict(), 1)]), Problem([IOExample(Dict(), 2)]), Problem([IOExample(Dict(), 3)])]
        problems_to_solutions::Dict{Problem, Vector{RuleNode}} = Dict(p => [] for p in subproblems)
        push!(problems_to_solutions[subproblems[1]], RuleNode(3, [RuleNode(2), RuleNode(1)]))
        push!(problems_to_solutions[subproblems[1]], RuleNode(4))
        push!(problems_to_solutions[subproblems[2]], RuleNode(13))
        push!(problems_to_solutions[subproblems[3]], RuleNode(23))

        @testset verbose=true "labels" begin
            
            expected_labels = ["RuleNode(3)", "RuleNode(13)", "RuleNode(23)"]
            labels = HerbSearch.get_labels(problems_to_solutions)
            @test length(labels) == 3
            @test labels == expected_labels
        end
        @testset verbose=true "predicates and features" begin
            # predicates
            n_predicates = 100
            sym_bool = :Condition
            predicates = HerbSearch.get_predicates(grammar, sym_bool, n_predicates)
            @test length(predicates) == n_predicates

            vec_problems_solutions = [(prob, sol[1]) for (prob, sol) in problems_to_solutions ]

            # features
        end
    end

    # TODO: Integration test for divide and conquer search procedure
end