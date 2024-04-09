using Logging
disable_logging(LogLevel(1))

function parametrized_test(argument_list, test_function::Function)
    method = methods(test_function)[begin]
    argument_names = [String(arg) for arg ∈ Base.method_argnames(method)[2:end]]
    function_name_string = String(Symbol(test_function))
    @testset "parameterized test: $function_name_string" verbose = true begin
        for arguments ∈ argument_list
            if length(arguments) != length(argument_names)
                error("""The length of the input arguments needs to match the length of the function params.
                       args given:      $arguments
                       function params: $argument_names""")
            end
            argument_pairs = ["$arg_name = $arg_value" for (arg_name,arg_value) in zip(argument_names, arguments)] 
            joined_names = join(argument_pairs,", ")
            @testset "$function_name_string($joined_names)" begin
                test_function(arguments...) 
            end
        end           
    end
end

function create_problem(f, range=20)
    examples = [IOExample(Dict(:x => x), f(x)) for x ∈ 1:range]
    return Problem(examples), examples
end
