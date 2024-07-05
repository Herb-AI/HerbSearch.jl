"""
    mine_fragments(grammar::AbstractGrammar, program::RuleNode)::Set{RuleNode}

Finds all the fragments from the provided `program`. The result is a set of the distinct fragments, generated recursively by going over all children.
A fragment is any complete subprogram of the original program.

# Arguments
- `grammar`: The grammar rules of the program.
- `program`: The program to mine fragments for.

# Returns
All the found fragments in the provided program.

"""
function mine_fragments(grammar::AbstractGrammar, program::RuleNode)::Set{RuleNode}
    fragments = Set{RuleNode}()
    # Push terminals as they are
    if isterminal(grammar, program)
        push!(fragments, program)
    else
        # Only complete programs count are considered
        if iscomplete(grammar, program)
            push!(fragments, program)
        end
        for child in program.children
            fragments = union(fragments, mine_fragments(grammar, child))
        end
    end
    fragments
end

"""
    mine_fragments(grammar::AbstractGrammar, programs::Set{RuleNode})::Set{RuleNode}

Finds all the fragments from the provided `programs` set. The result is a set of the distinct fragments found within all programs.
A fragment is any complete subprogram of the original program.

# Arguments
- `grammar`: The grammar rules of the program.
- `programs`: A set of programs to mine fragments for.

# Returns
All the found fragments in the provided programs.

"""
function mine_fragments(grammar::AbstractGrammar, programs::Set{RuleNode})::Set{RuleNode}
    fragments = reduce(union, mine_fragments(grammar, p) for p in programs)
    for program in programs
        delete!(fragments, program)
    end
    fragments
end

"""
    mine_fragments(grammar::AbstractGrammar, programs::Set{Tuple{RuleNode,Int,Int}}) -> Set{RuleNode}

Finds all the fragments from the provided `programs` set. The result is a set of the distinct fragments found within all programs.
A fragment is any complete subprogram of the original program.

# Arguments
- `grammar`: An abstract grammar object.
- `programs`: A set of programs, each also containing its node count and program length.

# Returns
All the found fragments in the provided programs.

"""
function mine_fragments(grammar::AbstractGrammar, programs::Set{Tuple{RuleNode,Int,Int}})::Set{RuleNode}
    fragments = reduce(union, mine_fragments(grammar, p) for (p, _, _) in programs)
    for program in programs
        delete!(fragments, program)
    end
    fragments
end

"""
    remember_programs!(
        old_remembered::Dict{BitVector, Tuple{RuleNode, Int, Int}}, passing_tests::BitVector, new_program::RuleNode, new_program_expr::Any, 
        fragments::AbstractVector{RuleNode}, grammar::AbstractGrammar)::Tuple{AbstractVector{RuleNode},Bool}

Updates the remembered programs by including `new_program` if it is simpler than all remembered programs that pass the same subset of tests, 
    and there is no simpler program passing a superset of the tests. It also removes any "worse" programs from the dictionary.

# Arguments
- `old_remembered`: The previously remembered programs, represented as a dictionary mapping `passed_tests` to (program's tree, the tree's `node_count`, `program_length`).
- `passing_tests`: A BitVector representing the passing test set for the new program.
- `new_program`: The new program to be considered for addition to the `old_remembered` dictionary.
- `new_program_expr`: The expression of the new program, used to calculate its length. If `nothing`, the length is set to 0.
- `fragments`: A set of the fragments mined from the `old_remembered` dictionary.
- `grammar`: The grammar rules of the program.

# Returns
The newly mined fragments from the updated remembered programs, and a flag to indicate if the new program was added to the dictionary.

"""
function remember_programs!(
    old_remembered::Dict{BitVector,Tuple{RuleNode,Int,Int}},
    passing_tests::BitVector,
    new_program::RuleNode,
    new_program_expr,
    fragments::AbstractVector{RuleNode},
    grammar::AbstractGrammar,
)::Tuple{AbstractVector{RuleNode},Bool}
    node_count = count_nodes(grammar, new_program)
    # Use program length only if an expression is provided -> saves time in many cases
    if new_program_expr === nothing
        program_length = 0
    else
        program_length = length(string(new_program_expr))
    end
    # Check the new program's testset over each remembered program
    for (key_tests, (_, p_node_count, p_program_length)) in old_remembered
        isSimpler = node_count < p_node_count || (node_count == p_node_count && program_length < p_program_length)
        # if the new program's passing testset is a subset of the old program's, discard new program if worse
        if all(passing_tests .== (passing_tests .& key_tests))
            if !isSimpler
                return fragments, false
            end
            # else if it is a superset -> discard old program if worse (either more nodes, or same #nodes but less tests)
        elseif all(key_tests .== (key_tests .& passing_tests))
            if isSimpler || (passing_tests != key_tests && node_count == p_node_count)
                delete!(old_remembered, key_tests)
            end
        end
    end
    # Add new program to remembered ones
    old_remembered[passing_tests] = (new_program, node_count, program_length)
    # println("Simplest program for tests: ", passing_tests)
    # println(rulenode2expr(new_program, grammar))
    collect(mine_fragments(grammar, Set(values(old_remembered)))), true
end