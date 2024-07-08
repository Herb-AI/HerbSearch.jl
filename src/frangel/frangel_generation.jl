"""
    modify_and_replace_program_fragments!(
        program::RuleNode, fragments::AbstractVector{RuleNode}, fragment_base_rules_offset::Int16, fragment_rules_offset::Int16, 
        config::FrAngelConfigGeneration, grammar::AbstractGrammar, rule_minsize::AbstractVector{UInt8}, 
        symbol_minsize::Dict{Symbol,UInt8}, use_angelic::Bool)::RuleNode

Recursively modifies and replaces program fragments based on specified rules and configurations.
The `X = Fragment_X` and `Fragment_X = ...` rules are replaced with non-fragment rules corresponding to the fragment's content, and are then possibly modified.

# Arguments
- `program`: The program to modify and replace fragments in.
- `fragments`: The collection of fragments to choose from.
- `fragment_base_rules_offset`: The offset for fragment base/identity rules.
- `fragment_rules_offset`: The offset for fragment rules.
- `config`: The configuration for program generation of FrAngel.
- `grammar`: The grammar rules of the program.
- `rule_minsize`: A vector of minimum sizes for each production rule in the grammar. Can be obtained from [`rules_minsize`](@ref).
- `symbol_minsize`: A dictionary with the minimum size achievable for each symbol in the grammar. Can be obtained from [`symbols_minsize`](@ref).
- `use_angelic`: A boolean flag indicating whether angelic conditions will be used.

# Returns
The modified program with replaced fragments.

"""
function modify_and_replace_program_fragments!(
    program::RuleNode,
    fragments::AbstractVector{RuleNode},
    fragment_base_rules_offset::Int16,
    fragment_rules_offset::Int16,
    config::FrAngelConfigGeneration,
    grammar::AbstractGrammar,
    use_angelic::Bool
)::RuleNode
    # If an identity fragment rule is picked -> fragments will be used
    if program.ind > fragment_base_rules_offset && program.ind <= fragment_rules_offset
        fragment_rule_index = program.children[1].ind
        # Either use entire fragment as is (replace by regular fragment rule)
        if rand() < config.use_entire_fragment_chance
            if use_angelic
                return deepcopy(fragments[fragment_rule_index-fragment_rules_offset])
            end
            return fragments[fragment_rule_index-fragment_rules_offset]
            # Or modify fragment
        else
            modified_fragment = deepcopy(fragments[fragment_rule_index-fragment_rules_offset])
            random_modify_children!(grammar, modified_fragment, config)
            return modified_fragment
        end
        # If non-fragment program -> traverse into its children to find other fragments for replacement
    elseif program.ind <= fragment_base_rules_offset
        if isterminal(grammar, program.ind)
            return program
        end
        for (index, child) in enumerate(program.children)
            program.children[index] = modify_and_replace_program_fragments!(child, fragments, fragment_base_rules_offset, fragment_rules_offset, config,
                grammar, use_angelic)
        end
        program
        # Cannot pick regular fragment rule directly; or an out-of-bounds index was chosen
    else
        println("Invalid rule index: ", program.ind)
    end
end

"""
    random_modify_children!(
        grammar::AbstractGrammar, node::RuleNode, config::FrAngelConfigGeneration)

Randomly modifies the children of a given node. The modification can be either a new random program or a modification of the existing children.
Only non-fragment rules are considered while modifiying by excluding rules with an index greater than `fragment_base_rules_offset`.

# Arguments
- `grammar`: The grammar rules of the program.
- `node`: The node to modify the children of.
- `config`: The configuration for program generation of FrAngel.

"""
function random_modify_children!(
    grammar::AbstractGrammar,
    node::RuleNode,
    config::FrAngelConfigGeneration
)
    for (index, child) in enumerate(node.children)
        # Generate a new program as a replacement
        if rand() < config.gen_similar_prob_new
            node.children[index] = rand(RuleNode, grammar, return_type(grammar, child), 2)#UInt8(length(child)) + config.similar_new_extra_size)
            # Traverse into the child
        else
            random_modify_children!(grammar, child, config)
        end
    end
end

"""
    get_replacements(node::RuleNode, grammar::AbstractGrammar, fragment_base_rules_offset::Int16)::AbstractVector{RuleNode}

Finds all the possible replacements for a given node in the AST. 
Looks for single-node trees corresponding to all variables and constants in the grammar, node descendants of the same symbol, and 
rules that have a subset of the current node's children (in the same order).

# Arguments
- `node`: The node to find replacements for.
- `grammar`: The grammar rules of the program.
- `fragment_base_rules_offset`: The offset for fragment base/identity rules.

# Returns
A vector of RuleNodes representing all the possible replacements for the provided node, ordered by size.

"""
function get_replacements(node::RuleNode, grammar::AbstractGrammar, fragment_base_rules_offset::Int16)::AbstractVector{RuleNode}
    replacements = Set{RuleNode}([])
    symbol = return_type(grammar, node)

    # The empty tree, if N⊤ is a statement in a block.
    children_types = child_types(grammar, node.ind)
    # Find all rules that can replace the current node, the replacement has to have a subse
    for rule_index in eachindex(grammar.rules)
        if grammar.types[rule_index] == symbol && length(child_types(grammar, rule_index)) < length(children_types)
            possible_replacement = RuleNode(rule_index)
            i = 1
            for c in child_types(grammar, rule_index)
                while i <= length(children_types) && c != children_types[i]
                    i += 1
                end

                if i <= length(children_types)
                    push!(possible_replacement.children, node.children[i])
                else
                    break
                end
            end

            if i <= length(children_types)
                push!(replacements, possible_replacement)
            end
        end
    end
    # Single-node trees/terminals, corresponding to all variables and constants in the grammar.
    for rule_index in eachindex(grammar.rules)
        if isterminal(grammar, rule_index) && return_type(grammar, rule_index) == symbol && rule_index <= fragment_base_rules_offset
            push!(replacements, RuleNode(rule_index))
        end
    end
    # D⊤ for all descendant nodes D of N.
    get_descendant_replacements!(node, symbol, grammar, replacements)
    # Order by replacement size
    sort!(collect(replacements), by=x -> length(x))
end

"""
    get_descendant_replacements!(node::RuleNode, symbol::Symbol, grammar::AbstractGrammar, replacements::AbstractSet{RuleNode})

Finds all the descendants of the same symbol for a given node in the AST.

# Arguments
- `node`: The node to find descendants in.
- `symbol`: The symbol to find descendants for.
- `grammar`: The grammar rules of the program.
- `replacements`: A set of RuleNodes to add the descendants to.

"""
function get_descendant_replacements!(node::RuleNode, symbol::Symbol, grammar::AbstractGrammar, replacements::AbstractSet{RuleNode})
    # Find all children with same type, and then recurse into their descendants
    for child in node.children
        if return_type(grammar, child) == symbol
            push!(replacements, child)
        end
        get_descendant_replacements!(child, symbol, grammar, replacements)
    end
end