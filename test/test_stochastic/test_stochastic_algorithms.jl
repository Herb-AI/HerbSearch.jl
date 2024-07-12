

grammar = @csgrammar begin
    X = |(1:5)
    X = X * X
    X = X + X
    X = X - X
    X = x
end

"""
Expression is an expression like x * x + x * x * x - 5 and max_depth is the max depth
"""
macro testmh(expression::String, max_depth=6)
    return :(
        @testset "mh $($expression)" begin
        e = Meta.parse("x -> $($expression)")
        problem, examples = create_problem(eval(e))
        iterator = MHSearchIterator(grammar, :X, examples, mean_squared_error, max_depth=$max_depth)
        solution, flag = synth(problem, iterator, max_time=MAX_RUNNING_TIME)
        @test flag == optimal_program
    end
    )
end

const global MAX_RUNNING_TIME = 10
macro testsa(expression::String,max_depth=6,init_temp = 2)
    return :(
        @testset "sa $($expression)" begin
        e = Meta.parse("x -> $($expression)")
        problem, examples = create_problem(eval(e))
        iterator = SASearchIterator(grammar, :X, examples, mean_squared_error, initial_temperature=$init_temp, max_depth=$max_depth)

        solution, flag = synth(problem, iterator, max_time=MAX_RUNNING_TIME)
        @test flag == optimal_program
    end
    )
end

macro testvlsn(expression::String, max_depth = 6, neighbourhood_depth = 4)
    return :(
        @testset "vl $($expression)" begin
        e = Meta.parse("x -> $($expression)")
        problem, examples = create_problem(eval(e))
        iterator = VLSNSearchIterator(grammar, :X, examples, mean_squared_error, neighbourhood_size=$neighbourhood_depth, max_depth=$max_depth)

        #@TODO overwrite evaluate function within synth to showcase how you may use that

        solution, flag = synth(problem, iterator, max_time=20)
        @test flag == optimal_program
    end
    )
end

@testset verbose = true "Algorithms" begin
    @testset verbose = true "MH" begin
        @testmh "x * x + 4" 3
        @testmh "x * (x + 5)" 4


        @testset verbose = true "factorization" begin
            @testmh  "5 * 5 * 5"         3  # 125 = 5 * 5 * 5 (depth 3)
            # @testmh  "5 * 5 * 5 * 5"     3  # 625 = 5 * 5 * 5 * 5 (depth 3)
            @testmh  "2 * 3 * 5 * 5"     3  # 150 = 2 * 3 * 5 * 5 (depth 3)
            @testmh  "2 * 2 * 3 * 4 * 5" 4  # 240 = ((2 * 2) * (3 * 4)) * 5 (depth 4)

        end
    end
    
    @testset verbose = true "Very Large Scale Neighbourhood" begin
        @testvlsn "2"  1 2
        @testvlsn "4"  1 4
        @testvlsn "x"  1 6
        @testvlsn "10" 3 20
        @testset "Specific tests" begin
            problem, examples = create_problem(x -> x * x * 5)
            @testset "Does not keep running BFS but stops after max_time" begin
                iterator = VLSNSearchIterator(grammar, :X, examples, mean_squared_error, neighbourhood_size=2, max_depth=3)

                runtime = @timed solution, flag = synth(problem, iterator, max_time=3)
                @test runtime.time <= 3 + 1
                @test flag == suboptimal_program
            end
            @testset "VLNS propose test" begin 
                solver = GenericSolver(grammar, RuleNode(6,[RuleNode(1),RuleNode(2)])) # start with 1 * x
                remove_node!(solver, [2])  # the tree is now 1 * hole

                iterations = 10
                iterator = VLSNSearchIterator(solver=deepcopy(solver), examples, mean_squared_error, neighbourhood_size=iterations, max_depth=3)
                proposed_programs_with_bfs = HerbSearch.propose(iterator, Vector{Int}(), nothing)
                programs = []
                for p ∈ proposed_programs_with_bfs
                    push!(programs, rulenode2expr(freeze_state(p), grammar))
                end
                
                @assert length(programs) == iterations
                @assert programs == [
                    :(1 * 1), :(1 *  2), :(1 * 3), :(1 *  4), :(1 * 5), :(1 * x),
                    :(1 * (1 * 1)), :(1 * (1 * 2)), :(1 * (1 * 3)), :(1 * (1 * 4))                    
                ]

                # even though the number of iterations is 10 the output is contrained by max_depth which is 2
                iterator = VLSNSearchIterator(solver=deepcopy(solver), examples, mean_squared_error, neighbourhood_size=iterations, max_depth=2)
                proposed_programs_with_bfs = HerbSearch.propose(iterator, Vector{Int}(), nothing)
                programs = []
                for p ∈ proposed_programs_with_bfs
                    push!(programs, rulenode2expr(freeze_state(p), grammar))
                end

                @assert programs == [
                    :(1 * 1), :(1 *  2), :(1 * 3), :(1 *  4), :(1 * 5), :(1 * x), # programs of depth 2
                ]

                @testset "Try improve prorgam gives the best possiblity" begin
                    problem, examples = create_problem(x -> 3)
                    iterator = VLSNSearchIterator(grammar, :X, examples, mean_squared_error, neighbourhood_size=10, max_depth=2)
                    options = BFSIterator(grammar, :X, max_depth=1)

                    output = HerbSearch.try_improve_program!(iterator, options, 1, 100.0) # best cost is 100
                    # bfs can find the program "3" that achieves cost "0"
                    @test rulenode2expr(output, grammar) == :(3)

                    # complex problem
                    problem, examples = create_problem(x -> 50)
                    iterator = VLSNSearchIterator(grammar, :X, examples, mean_squared_error, neighbourhood_size=10, max_depth=2)
                    output = HerbSearch.try_improve_program!(iterator, options, 1, 0.0) # <- cost of 0. Every BFS program will have higher cost than 0
                    # -> No program has better cost than 0 -> output = nothing
                    @test isnothing(output)
                end
            end
            
        end 
    end
    
    @testset verbose = true "Simulated Annealing" begin
        @testsa "x * x + 4" 3
        @testsa "x * (x + 5)" 3 2

        @testset verbose = true "factorization" begin
            @testsa  "5 * 5"             2  # 25 = 5 * 5 (depth 2)
            @testsa  "2 * 3 * 4"         3  # (depth 3)
        end
    end
end
