global const runs = 1000

function test_is_true_on_percentage(function_call::Function, percentage::Real)
    count = 0
    for _ in 1:runs
        outcome = function_call()
        if outcome 
            count = count + 1
        end
    end
    @test count >= (percentage - 0.2) * runs 
end


@testset "Probabilistic accept" verbose=true begin 
    parametrized_test(
        [
            [1, 1, 0.5],
            [1, 3, 0.25],
            [1, 9, 0.1],
            [10, 1, 1]
        ],
        function probabilistic_accept_on_percentage(current_cost, next_cost, percentage)
            test_is_true_on_percentage(() -> HerbSearch.probabilistic_accept(current_cost, next_cost, 0), percentage)
        end
    )
end

