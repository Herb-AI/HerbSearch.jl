function string_interpret(prog::AbstractRuleNode, grammar::ContextSensitiveGrammar, example::IOExample, new_rules_decoding::Dict)
    tags = HerbBenchmarks.String_transformations_2020.get_relevant_tags(grammar)
    string_interpret(prog, tags, example.in[:_arg_1], new_rules_decoding)
end

function string_interpret_if(prog::AbstractRuleNode, grammartags::Dict{Int,Symbol}, state::HerbBenchmarks.String_transformations_2020.StringState, d::Dict)
    if prog.children[1] isa Hole
        return state
    else
        string_interpret(prog.children[1], grammartags, state, d) ? string_interpret(prog.children[2], grammartags, state, d) : string_interpret(prog.children[3], grammartags, state, d)
    end
end

function string_interpret_while(prog::AbstractRuleNode, grammartags::Dict{Int,Symbol}, state::HerbBenchmarks.String_transformations_2020.StringState, d::Dict)
    if prog.children[1] isa Hole
        return state
    else
        string_command_while(prog.children[1], prog.children[2], grammartags, state, d)
    end
end

function string_command_while(condition::AbstractRuleNode, body::AbstractRuleNode, grammartags::Dict{Int,Symbol}, state::HerbBenchmarks.String_transformations_2020.StringState, d::Dict, max_steps::Int=1000)
    counter = 5 * length(state.str)
    while string_interpret(condition, grammartags, state, d) && counter > 0
        new_state = string_interpret(body, grammartags, state, d)

        if new_state == state
            break
        end
        state = new_state

        counter -= 1
    end
    state
end

function string_interpret(prog::AbstractRuleNode, grammartags::Dict{Int,Symbol}, state::HerbBenchmarks.String_transformations_2020.StringState, new_rules_decoding::Dict)
    if prog isa Hole
        return state
    end
    
    ss = HerbBenchmarks.String_transformations_2020.StringState
    d = new_rules_decoding

    prog = sub_new_rules(prog, d)
    
    rule_node = get_rule(prog)
    # if rule_node in keys(d)
    #     println("$prog")
    #     println(d[rule_node])
    #     println("Apply 27 on $(state.str)")
    #     res = string_interpret(d[rule_node], grammartags, state, d)
    #     println("Result $(res.str) \n")
    #     return res
    # end

    @match grammartags[rule_node] begin
        :OpSeq => string_interpret(prog.children[2], grammartags, string_interpret(prog.children[1], grammartags, state, d), d) # (Operation ; Sequence)
        :moveRight => ss(state.str, min(state.pointer + 1, length(state.str))) # moveRight
        :moveLeft => ss(state.str, max(state.pointer - 1, 1))   # moveLeft
        :makeUppercase => ss(state.str[1:state.pointer-1] * uppercase(state.str[state.pointer]) * state.str[state.pointer+1:end], state.pointer) #MakeUppercase
        :makeLowercase => ss(state.str[1:state.pointer-1] * lowercase(state.str[state.pointer]) * state.str[state.pointer+1:end], state.pointer) #makeLowercase
        :drop => state.pointer < length(state.str) ? ss(state.str[1:state.pointer-1] * state.str[state.pointer+1:end], state.pointer) : ss(state.str[1:state.pointer-1] * state.str[state.pointer+1:end], state.pointer - 1) #drop
        :IF => string_interpret_if(prog, grammartags, state, d) # if statement
        :WHILE => string_interpret_while(prog, grammartags, state, d) # while statement
        :atEnd => state.pointer == length(state.str) # atEnd
        :notAtEnd => state.pointer != length(state.str) # notAtEnd
        :atStart => state.pointer == 1 # atStart
        :notAtStart => state.pointer != 1 # notAtStart
        :isLetter => state.pointer <= length(state.str) && isletter(state.str[state.pointer]) # isLetter
        :isNotLetter => state.pointer > length(state.str) || !isletter(state.str[state.pointer]) # isNotLetter
        :isUppercase => state.pointer <= length(state.str) && isuppercase(state.str[state.pointer]) # isUpperCase 
        :isNotUppercase => state.pointer > length(state.str) || !isuppercase(state.str[state.pointer]) # isNotUppercase
        :isLowercase => state.pointer <= length(state.str) && islowercase(state.str[state.pointer]) # isLowercase
        :isNotLowercase => state.pointer > length(state.str) || !islowercase(state.str[state.pointer]) # isNotLowercase
        :isNumber => state.pointer <= length(state.str) && isdigit(state.str[state.pointer]) # isNumber
        :isNotNumber => state.pointer > length(state.str) || !isdigit(state.str[state.pointer]) # isNotNumber
        :isSpace => state.pointer <= length(state.str) && isspace(state.str[state.pointer]) # isSpace
        :isNotSpace => state.pointer > length(state.str) || !isspace(state.str[state.pointer]) # isNotSpace
        _ => string_interpret(prog.children[1], grammartags, state, d)
    end

end

function sub_new_rules(prog::AbstractRuleNode, new_rules_decoding::Dict)
    rule_node = get_rule(prog)

    if rule_node in keys(new_rules_decoding)
        # println("Sub $prog")
        @assert length(prog.children) == 1
        prog = sub_hole(deepcopy(new_rules_decoding[rule_node]), prog.children[1])
        # println("Res $prog")
    end

    return prog
end

function sub_hole(prog::AbstractRuleNode, hole::AbstractRuleNode)
    if prog isa Hole
        return hole
    end

    if length(prog.children) == 0
        return prog
    end

    prog.children = [sub_hole(c, hole) for c in prog.children]

    return prog
end

function synth_program(problems::Vector, grammar::ContextSensitiveGrammar, benchmark, gr_key, extra_rules)
    string_grammar_size = 26
    new_rules_decoding = Dict()
    if length(grammar.rules) > string_grammar_size
        i = 1
        while string_grammar_size + i <= length(grammar.rules)
            new_rules_decoding[string_grammar_size + 1] = deepcopy(extra_rules[i])
            i += 1
        end
    end

    problems = first(problems, 5)

    function string_cost(program, print=false)
        sources = []
        targets = [problem.out.str for problem in problems]
        pointers = []

        for problem in problems
            try
                res = string_interpret(program, grammar, problem, new_rules_decoding)
                push!(sources, res.str)
                push!(pointers, res.pointer)
            catch e
                if isa(e, BoundsError)
                    return Inf
                else
                    rethrow(e)
                end
            end
        end

        if print || false
            println("\n")
            println(program)
            println([problem.in[:_arg_1].str for problem in problems])
            println(sources)
            println(targets)
        end

        cost = string_heuristic!(sources, targets, pointers)

        return cost
    end

    iterator = BestFirstIterator(grammar, gr_key, string_cost)


    count = 0
    start_time = time()

    solved = false
    last_program = nothing
    last_cost = -1
    for (program, cost) ∈ iterator
        yield()

        # if count % 1 == 0
        #     println("Iteration: $count, cost: $cost, program: $program")
        # end

        count += 1
        last_program = program
        last_cost = cost


        if cost == 0
            solved = true
            # last_program = program
            # last_cost = cost
            # println(string_cost(program, true))
            break
        end

        if count == 1000
            # string_cost(program, true)
            break
        end
    end

    return solved, last_program, last_cost, count, time() - start_time
end

# 100 problems, 5 examples per problem, 1000 iterations
# Levensthein   depth       11 / 100