
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

levenshtein_aux = AuxFunction(
    (expected::IOExample{<:Any,<:AbstractString}, actual::AbstractString) ->
        levenshtein!(expected.out, actual, 1, 1, 1),
    problem::Problem -> begin
        score = 0
        for example ∈ problem.spec
            score += levenshtein!(example.out, only(values(example.in)), 1, 1, 1)
        end
        return score
    end,
    0
)

simple_grammar = @csgrammar begin
    String = " "
    String = "<"
    String = ">"
    String = "-"
    String = "."
    String = x
    String = String * String
    String = replace(String, String => "")
end

@testset "Example Appending" begin
    problem = Problem([
        IOExample(Dict(:x => "1"), "1."),
        IOExample(Dict(:x => "2"), "2."),
        IOExample(Dict(:x => "3"), "3.")
    ])
    g = deepcopy(simple_grammar)
    opts = AulileOptions(synth_opts=SynthOptions(eval_opts=EvaluateOptions(aux=levenshtein_aux)))
    test_result = aulile(problem, BFSIterator, g, :String, opts=opts)
    @test !(test_result.program isa Nothing)
    @test test_result.score == levenshtein_aux.best_value
    program = rulenode2expr(test_result.program, g)
end

@testset "Example Replacing" begin
    problem = Problem([
        IOExample(Dict(:x => "1."), "1"),
        IOExample(Dict(:x => "2."), "2"),
        IOExample(Dict(:x => "3."), "3")
    ])
    g = deepcopy(simple_grammar)
    opts = AulileOptions(synth_opts=SynthOptions(eval_opts=EvaluateOptions(aux=levenshtein_aux)))
    test_result = aulile(problem, BFSIterator, g, :String, opts=opts)
    @test !(test_result.program isa Nothing)
    @test test_result.score == levenshtein_aux.best_value
    program = rulenode2expr(test_result.program, g)
end

PRINT_FLAG = false

@testset "Aulile Example from Paper" begin
    problem = Problem([
        IOExample(Dict(:x => "801-456-8765"), "8014568765"),
        IOExample(Dict(:x => "<978> 654-0299"), "9786540299"),
        IOExample(Dict(:x => "978.654.0299"), "9786540299")
    ])
    g = deepcopy(simple_grammar)
    opts = AulileOptions(max_depth=2, synth_opts=SynthOptions(skip_old_programs=false,
        eval_opts=EvaluateOptions(aux=levenshtein_aux), num_returned_programs=2, print_debug=PRINT_FLAG))
    elapsed = @elapsed begin
        test_result = aulile(problem, BFSIterator, g, :String, opts=opts)
        @test !(test_result.program isa Nothing)
        @test test_result.score == levenshtein_aux.best_value
        program = rulenode2expr(test_result.program, g)
    end
    if PRINT_FLAG
        println("Program: $(program), time: $(elapsed)s, enums: $(test_result.enumerations)")
        println("=========================")
    end
end

@testset "Aulile Example from Paper, with restart" begin
    problem = Problem([
        IOExample(Dict(:x => "801-456-8765"), "8014568765"),
        IOExample(Dict(:x => "<978> 654-0299"), "9786540299"),
        IOExample(Dict(:x => "978.654.0299"), "9786540299")
    ])
    g = deepcopy(simple_grammar)
    opts = AulileOptions(max_depth=2, synth_opts=SynthOptions(
        eval_opts=EvaluateOptions(aux=levenshtein_aux), num_returned_programs=2, print_debug=PRINT_FLAG))
    elapsed = @elapsed begin
        test_result = aulile(problem, BFSIterator, g, :String, opts=opts)
        @test !(test_result.program isa Nothing)
        @test test_result.score == levenshtein_aux.best_value
        program = rulenode2expr(test_result.program, g)
    end
    if PRINT_FLAG
        println("Program: $(program), time: $(elapsed)s, enums: $(test_result.enumerations)")
        println("=========================")
    end
end

