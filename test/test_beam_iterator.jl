
simple_grammar = @cfgrammar begin
    Int = 1 | 2
    Int = Int + Int
    Int = Int - Int
end

complex_grammar = @cfgrammar begin
    Int = 1 | 2
    Int = Int + Int
    Int = Int - Int
    Float = 0.1 | 0.01
    Float = Int / Int
    Float = Float * Float
    Float = Float * Int
    Float = Float + Int
    Float = Float / Float
end

function interp(rulenode)
    r = get_rule(rulenode)
    cs = [interp(c) for c in get_children(rulenode)]

    if     r == 1
        return 1
    elseif r == 2
        return 2
    elseif r == 3
        return cs[1] + cs[2]
    elseif r == 4
        return cs[1] - cs[2]
    elseif r == 5
        return 0.1
    elseif r == 6
        return 0.01
    elseif r == 7
        return cs[1] / cs[2]
    elseif r == 8
        return cs[1] * cs[2]
    elseif r == 9
        return cs[1] * cs[2]
    elseif r == 10
        return cs[1] + cs[2]
    elseif r == 11
        return cs[1] / cs[2]
    end
end

heuristic(target, rulenode) = abs(interp(rulenode) - target)

function beam_test(grammar, iterator, expected_programs)
    for program in iterator
        !isempty(expected_programs) || break
        expected_program = popfirst!(expected_programs)
        program = rulenode2expr(program, grammar)
        @test program == expected_program
        
    end
end

@testset "Beam iterator" begin

    @testset "Simple grammar" begin

        @testset "Extension depth = 1, stop expanding beam once replaced, no observational equivalance" begin

            @testset "Heuristic = |y - 10|" beam_test(simple_grammar,
                BeamIterator(simple_grammar, :Int,
                    beam_size = 2,
                    max_extension_depth = 1,
                    max_extension_size = 1,
                    program_to_cost = r -> heuristic(10, r),
                    stop_expanding_beam_once_replaced = true,
                    interpreter = interp,
                    observational_equivalance = false,
                ), [
                    :(2), :(1),
                    :(2 + 2), :(2 + 1),
                    :(2 + (2 + 2)), :((2 + 2) + 2),
                    :(2 + (2 + (2 + 2))), :((2 + (2 + 2)) + 2),
                ])

            @testset "Target of heuristic = |y - (-10)|" beam_test(simple_grammar,
                BeamIterator(simple_grammar, :Int,
                    beam_size = 2,
                    max_extension_depth = 1,
                    max_extension_size = 1,
                    program_to_cost = r -> heuristic(-10, r),
                    stop_expanding_beam_once_replaced = true,
                    interpreter = interp,
                    observational_equivalance = false,
                ), [
                    :(1), :(2),
                    :(1 - 2), :(1 - 1),
                    :((1 - 2) - 2), :((1 - 2) - 1),
                    :(((1 - 2) - 2) - 2), :(((1 - 2) - 2) - 1),
                ])

            @testset "Target of heuristic = |y - (2.9)|" beam_test(simple_grammar,
                BeamIterator(simple_grammar, :Int,
                    beam_size = 2,
                    max_extension_depth = 1,
                    max_extension_size = 1,
                    program_to_cost = r -> heuristic(2.9, r),
                    stop_expanding_beam_once_replaced = true,
                    interpreter = interp,
                    observational_equivalance = false,
                ), [
                    :(2), :(1),
                    :(1 + 2), :(2 + 1),
                ])
        end

        @testset "Extension depth = 2, stop expanding beam once replaced, no observational equivalance" begin

            @testset "Heuristic = |y - 10|" beam_test(simple_grammar,
                BeamIterator(simple_grammar, :Int,
                    beam_size = 2,
                    max_extension_depth = 2,
                    max_extension_size = 3,
                    program_to_cost = r -> heuristic(10, r),
                    stop_expanding_beam_once_replaced = true,
                    interpreter = interp,
                    observational_equivalance = false,
                ), [
                    :(2 + 2), :(2 + 1),
                    :((2 + 2) + (2 + 2)), :((2 + 2) + (2 + 1)),
                    :(((2 + 2) + (2 + 2)) + (1 + 1)), :(((2 + 2) + (2 + 2)) + 2),
                ])

            @testset "Target of heuristic = |y - (-10)|" beam_test(simple_grammar,
                BeamIterator(simple_grammar, :Int,
                    beam_size = 2,
                    max_extension_depth = 2,
                    max_extension_size = 3,
                    program_to_cost = r -> heuristic(-10, r),
                    stop_expanding_beam_once_replaced = true,
                    interpreter = interp,
                    observational_equivalance = false,
                ), [
                    :(1 - 2), :(1 - 1),
                    :((1 - 2) - (2 + 2)), :((1 - 2) - (2 + 1)),
                ])
        end
    end

    @testset "Complex grammar" begin

        @testset "Extension depth = 1, stop expanding beam once replaced, no observational equivalance" begin

            @testset "Heuristic = |y - 10|" beam_test(complex_grammar,
                BeamIterator(complex_grammar, :Float,
                    beam_size = 2,
                    max_extension_depth = 1,
                    max_extension_size = 1,
                    program_to_cost = r -> heuristic(10, r),
                    stop_expanding_beam_once_replaced = true,
                    interpreter = interp,
                    observational_equivalance = false,
                ), [
                    :(0.1), :(0.01),
                    :(0.1 / 0.01), :(0.1 + 2),
                    :((0.1 / 0.01) * 1)
                ])

            @testset "Target of heuristic = |y - (-10)|" beam_test(complex_grammar,
                BeamIterator(complex_grammar, :Float,
                    beam_size = 2,
                    max_extension_depth = 1,
                    max_extension_size = 1,
                    program_to_cost = r -> heuristic(-10, r),
                    stop_expanding_beam_once_replaced = true,
                    interpreter = interp,
                    observational_equivalance = false,
                ), [
                    :(0.01), :(0.1),
                    :(0.01 * 0.01), :(0.01 * 0.1),
                ])

            @testset "Target of heuristic = |y - (2.9)|" beam_test(complex_grammar,
                BeamIterator(complex_grammar, :Float,
                    beam_size = 2,
                    max_extension_depth = 1,
                    max_extension_size = 1,
                    program_to_cost = r -> heuristic(2.9, r),
                    stop_expanding_beam_once_replaced = true,
                    interpreter = interp,
                    observational_equivalance = false,
                ), [
                    :(0.1), :(0.01),
                    :(0.1 + 2), :(0.1 + 1),
                    :((0.1 + 2) + 1), :((0.1 + 2) * 1),
                ])
        end

        @testset "Extension depth = 2, stop expanding beam once replaced, no observational equivalance" begin

            @testset "Heuristic = |y - 10|" beam_test(complex_grammar,
                BeamIterator(complex_grammar, :Float,
                    beam_size = 2,
                    max_extension_depth = 2,
                    max_extension_size = 3,
                    program_to_cost = r -> heuristic(10, r),
                    stop_expanding_beam_once_replaced = true,
                    interpreter = interp,
                    observational_equivalance = false,
                ), [
                    :(0.1 / 0.01), :(0.1 + 2),
                    :((0.1 / 0.01) * (1 / 1)), :((1 / 1) * (0.1 / 0.01)),
                ])

            @testset "Target of heuristic = |y - (-10)|" beam_test(complex_grammar,
                BeamIterator(complex_grammar, :Float,
                    beam_size = 2,
                    max_extension_depth = 2,
                    max_extension_size = 3,
                    program_to_cost = r -> heuristic(-10, r),
                    stop_expanding_beam_once_replaced = true,
                    interpreter = interp,
                    observational_equivalance = false,
                ), [
                    :(0.01 * 0.01), :(0.01 * 0.1),
                    :((0.01 * 0.01) + (1 - 2)), :((0.01 * 0.01) * (1 - 2)),
                ])
        end
    end
end