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

function aulile_levenstein(
    expected::IOExample{<:Any,<:AbstractString},
    actual::AbstractString)::Int
    return levenshtein!(expected.out, actual, 1, 1, 1) # Equal costs for each mistake type
end

g = @csgrammar begin
    String = " "
    String = "<"
    String = ">"
    String = "-"
    String = "."
    String = " "
    String = "0"
    String = "1"
    String = "2"
    String = "3"
    String = "4"
    String = "5"
    String = "6"
    String = "7"
    String = "8"
    String = "9"
    String = x
    String = String * String
    String = replace(String, String => "")
end

@testset "Example Appending" begin
    println("-----------------")
    problem = Problem([
        IOExample(Dict(:x => "1"), "1."),
        IOExample(Dict(:x => "2"), "2."),
        IOExample(Dict(:x => "3"), "3.")
    ])
    iterator = BFSIterator(g, :String, max_depth=5)

    test_result = aulile(problem, iterator, :String, aulile_levenstein)
    @test !(test_result isa Nothing)
    solution, flag = test_result
    program = rulenode2expr(solution, g)
    println(program)

    @test !(solution isa Nothing)
end

@testset "Example Replacing" begin
    println("-----------------")
    problem = Problem([
        IOExample(Dict(:x => "1."), "1"),
        IOExample(Dict(:x => "2."), "2"),
        IOExample(Dict(:x => "3."), "3")
    ])
    iterator = BFSIterator(g, :String, max_depth=5)

    test_result = aulile(problem, iterator, :String, aulile_levenstein)
    @test !(test_result isa Nothing)
    solution, flag = test_result
    program = rulenode2expr(solution, g)
    println(program)

    @test !(solution isa Nothing)
end

@testset "Aulile Example from Paper" begin
    println("-----------------")

    problem = Problem([
        IOExample(Dict(:x => "801-456-8765"), "8014568765"),
        IOExample(Dict(:x => "<978> 654-0299"), "9786540299"),
        IOExample(Dict(:x => "978.654.0299"), "9786540299")
    ])
    iterator = BFSIterator(g, :String, max_depth=2)

    test_result = aulile(problem, iterator, :String, aulile_levenstein)
    @test !(test_result isa Nothing)
    solution, flag = test_result
    program = rulenode2expr(solution, g)
    println(program)

    @test true
end

