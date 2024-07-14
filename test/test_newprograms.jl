function bruteforce(nr_elements, desired_sum, maximum_value)
    iterators = []
    for i ∈ 1:nr_elements
        push!(iterators, (1:maximum_value))
    end
    options = Iterators.product(iterators...)
    solutions = []
    for costs ∈ options
        if sum(costs) == desired_sum
            push!(solutions, [costs...])
        end
    end
    return solutions
end
function fast_sol(nr_elements, desired_sum, maximum_value)
    sum_iter = HerbSearch.SumIterator(nr_elements, desired_sum, maximum_value)
    array = []
    for el ∈ sum_iter
        push!(array, deepcopy(el))
    end
    return array
end
@testset "Test that the sum iterator works" begin

    @testset "Property based testing" begin
        max_value = 10
        nr_runs = 10 
        random_inputs = [(rand(1:max_value), rand(1:max_value), rand(1:max_value)) for _ in 1:nr_runs]

        parametrized_test(random_inputs, function test_sum_generation(nr_elements, desired_sum, maximum_value)
            my_sol = fast_sol(nr_elements, desired_sum, maximum_value)
            for el ∈ my_sol 
                @test sum(el) == desired_sum
                @test all(el .<= maximum_value)
                @test length(el) == nr_elements
            end
            brute = bruteforce(nr_elements, desired_sum, maximum_value)
            @test sort(my_sol) == sort(brute)

        end)
    end
    @testset "Edge case test with one element" begin 
        sum_iter = HerbSearch.SumIterator(number_of_elements=1, desired_sum=5, max_value=6)
        options = Vector{Vector{Int}}()
        for option ∈ sum_iter
            # deep copy is needed because the iterator mutates the state in place
            push!(options, deepcopy(option))
        end
        @test options == [[5]]
    end
    @testset "Length based tests" begin
        HerbSearch.calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = HerbSearch.calculate_rule_cost_size(rule_index, grammar)
        # impossible to sum up to 3 using 2 numbers that are at most 1
        sum_iter = HerbSearch.SumIterator(number_of_elements=2, desired_sum=3, max_value=1)
        @test isnothing(iterate(sum_iter))

        sum_iter = HerbSearch.SumIterator(number_of_elements=4, desired_sum=5, max_value=2)
        options = Vector{Vector{Int}}()
        for option ∈ sum_iter
            # deep copy is needed because the iterator mutates the state in place
            push!(options, deepcopy(option))
        end
        @test options == [
            [1, 1, 1, 2],
            [1, 1, 2, 1],
            [1, 2, 1, 1],
            [2, 1, 1, 1]
        ]
    end
end
@testset "Test new programs iterator" begin
    @testset "Multiple nonterminals" begin
        grammar = @pcsgrammar begin
            1 : S = A * B
            1 : A = "a"
            1 : B = "b"
        end

        bank = [[],[],[],[]]
        for i in 1:3
            iter = HerbSearch.NewProgramsIterator(i, bank, grammar)
            for prog in iter
                push!(bank[i+1], prog)
            end
        end

        @test bank == [
            [],
            [RuleNode(2), RuleNode(3)],
            [],
            [RuleNode(1, [RuleNode(2), RuleNode(3)])]
        ]
    end
end