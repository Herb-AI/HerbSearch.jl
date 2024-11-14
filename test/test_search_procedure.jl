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

    @testset verbose =true "divide" begin
        problem = Problem([IOExample(Dict(), x) for x ∈ 1:3])
        expected_subproblems = [Problem([IOExample(Dict(), 1)]), Problem([IOExample(Dict(), 2)]), Problem([IOExample(Dict(), 3)])]
        subproblems = divide_by_example(problem) 
        println(subproblems[1])
        println(expected_subproblems[1])
        println(typeof(subproblems[1]) == typeof(expected_subproblems[1]))
        println(typeof(subproblems[1].spec))

        
        
    end

    @testset verbose =true "decide" begin

    end

    @testset verbose =true "conquer" begin

    end

    # TODO: Test for divide and conquer search procedure
end