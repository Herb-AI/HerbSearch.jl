arithmetic_grammar = @csgrammar begin
    X = |(1:5)
    X = X * X
    X = X + X
    X = X - X
    X = x
end

function create_problem(f, repr::String, range=20)
    examples = [IOExample(Dict(:x => x), f(x)) for x ∈ 1:range]
    return Problem(examples), repr
end

problems_train = [
    create_problem(x -> x + 10,"x -> x + 10"),
    create_problem(x -> (x + 10) * x + 5,"x -> (x + 10) * x + 5"),
    create_problem(x -> 5 * x * x * x + 10,"x -> 5 * x * x * x + 10"),
    create_problem(x -> (x + 8) * (x - 5) * x + 20,"x -> (x + 8) * (x - 5) * x + 20"),
    create_problem(x -> x * x * x * x * x + 2,"x * x * x * x * x + 2"),
    create_problem(x -> (x + 2) * x * x + (x - 1) * x - 2,"(x + 2) * x * x + (x - 1) * x - 2"),
]
  
problems_test = [
    create_problem(x -> x * x * x + 10,"x -> x * x * x + 10"),
    create_problem(x -> x * x * x * x * x + x * 2 * x,"x -> x * x * x * x * x + x * 2 * x"),
    create_problem(x -> x * x * x - 4 * x * x + x + 5,"x -> x * x * x - 4 * x * x + x + 5"),
    create_problem(x -> x * (2 - x) * (x + 4) * x,"x -> x * (2 - x) * (x + 4) * x"),
    create_problem(x -> 15 * x * (x + 2) * (x - 40) ,"x -> x * (2 - x) * (x + 4) * x"),
]
  