abstract type BottomUpIterator <: ProgramIterator end

@programiterator BasicIterator(problem::Problem{Vector{IOExample}}) <: BottomUpIterator

function order(
    ::BottomUpIterator,
    grammar::ContextSensitiveGrammar
)
    return order(BasicIterator, grammar)
end

function pick(
    ::BottomUpIterator,
    grammar::ContextSensitiveGrammar,
    bank::Dict{RuleNode,Int64},
    rule::Int64
)
    return pick(BasicIterator, grammar, bank, rule)
end

function priority_function(
    ::BottomUpIterator,
    program::RuleNode
)
    return priority_function(BasicIterator, program)
end

# =========Here starts the default implementation of the bottom-up iterator==========

struct BottomUpState
    priority_bank::Dict{RuleNode,Int64}
    hashes::Set{Int128}
    current_programs::Queue{RuleNode}
end

function order(
    ::BasicIterator,
    grammar::ContextSensitiveGrammar
)
    return findall(isterminal -> !isterminal, grammar.isterminal)
end

function pick(
    ::BasicIterator,
    grammar::ContextSensitiveGrammar,
    state::BottomUpState,
    rule::Int64
)::Vector{RuleNode}
    new_programs = []
    childtypes = grammar.childtypes[rule]

    permuatations = Combinatorics.permutations(collect(keys(state.priority_bank)), length(childtypes))

    for rulenode_permutation ∈ permuatations
        if map(rulenode -> grammar.types[rulenode.ind], rulenode_permutation) == childtypes
            new_single_program = RuleNode(rule, nothing, rulenode_permutation)

            push!(new_programs, new_single_program)
        end
    end

    return new_programs
end

function priority_function(
    ::BasicIterator,
    program::RuleNode,
    state::BottomUpState
)::Int64
    retval::Int64 = 0

    for child ∈ program.children
        retval = max(retval, state.priority_bank[child])
    end

    return retval + 1
end



function Base.iterate(iter::BottomUpIterator)::Union{Nothing,Tuple{RuleNode,BottomUpState}}
    current_programs = Queue{RuleNode}()
    bank::Base.Dict{RuleNode,Int64} = Dict()
	hashes::Set{Int128} = Set{Int128}()

	println("From first iterate")
    for terminal in findall(iter.grammar.isterminal)
        current_single_program::RuleNode = RuleNode(terminal, nothing, [])

        enqueue!(current_programs, current_single_program)
        bank[current_single_program] = 1
    end

    state::BottomUpState = BottomUpState(bank, hashes, current_programs)
	println("end of first iterate")
    return _get_next_program(iter, state)
end

function Base.iterate(iter::BottomUpIterator, state::BottomUpState)
    next_program = _get_next_program(iter, state)
    if next_program ≠ nothing
        return next_program
    end

    rules::Vector{Int64} = order(iter, iter.grammar)
    for rule in rules
        new_programs = pick(iter, iter.grammar, state, rule)
        for new_program ∈ new_programs

            enqueue!(state.current_programs, new_program)
        end
    end

    return _get_next_program(iter, state)
end

function _get_next_program(
    iter::BottomUpIterator,
    state::BottomUpState
)::Union{Nothing,Tuple{RuleNode, BottomUpState}}


    while !isempty(state.current_programs) && _contains_equivalent_(iter, state, first(state.current_programs))
        dequeue!(state.current_programs)
    end

    if isempty(state.current_programs)
        return nothing
    end

    new_program::RuleNode = dequeue!(state.current_programs)
    # println("from before bank")
    state.priority_bank[new_program] = priority_function(iter, new_program, state)
    # state.hashed_output_bank[new_program] = _hash_outputs_for_program(new_program, iter.problem)
    # println("from after: ", state.bank[new_program])
    # println("Depth: ", depth(new_program))
	# println(_hash_outputs_for_program(iter, new_program, iter.problem))
    println(rulenode2expr(new_program, iter.grammar))
    return new_program, state
end


function _contains_equivalent_(
	iter::BottomUpIterator,
	state::BottomUpState,
	program::RuleNode
)::Bool
	hashed_output = _hash_outputs_for_program(iter, program, iter.problem)

	if hashed_output ∈ state.hashes
		# println("Found equivalent", rulenode2expr(program, iter.grammar))
		return true
	end

	push!(state.hashes, hashed_output)
	return false
end



function _hash_outputs_for_program(
	iter::BottomUpIterator,
	new_program::RuleNode,
    problem::Problem{Vector{IOExample}}
)::UInt
    retval::UInt = 0

    for example ∈ problem.spec
        output = execute_on_input(SymbolTable(iter.grammar), rulenode2expr(new_program, iter.grammar), example.in)
        retval = hash(retval ⊻ hash(output))
    end

    return retval
end
