"""
    generate_random_program(grammar::AbstractGrammar, type::Symbol, fragments::Set{RuleNode}, config::FrAngelConfig, generate_with_angelic::Bool, max_size=40, disabled_fragments=false)::Union{RuleNode, Nothing}

Generates a random program of the provided `type` using the provided `grammar`. The program is generated with a maximum size of `max_size` and can use fragments from the provided set.

# Arguments
- `grammar`: An abstract grammar object.
- `type`: The type of the program to generate.
- `fragments`: A set of RuleNodes representing the fragments that can be used in the program generation.
- `config`: A FrAngelConfig object containing the configuration for the random program generation.
- `generate_with_angelic`: A float representing the chance to generate a program with an angelic condition. Set to 0 if no such conditions are desired.
- `max_size`: The maximum size of the program to generate.
- `disabled_fragments`: A boolean flag to disable the use of fragments in the program generation.

# Returns
A random program of the provided type, or nothing if no program can be generated.
"""
function generate_random_program(
    grammar::AbstractGrammar,
    type::Symbol,
    fragments::Set{RuleNode},
    config::FrAngelConfig,
    generate_with_angelic::Float16,
    max_size=40,
    disabled_fragments=false
)::Union{RuleNode,Nothing}
    if max_size < 0
        return nothing
    end
    use_fragments = !disabled_fragments && rand() < config.random_generation_use_fragments_chance
    if use_fragments
        possible_fragments = filter(f -> return_type(grammar, f) == type, fragments)
        if !isempty(possible_fragments)
            # Pick a fragment, either return itself or modify a child with it
            fragment = deepcopy(rand(possible_fragments))
            if rand() < config.random_generation_use_entire_fragment_chance
                return fragment
            end
            random_modify_children!(grammar, fragment, config, generate_with_angelic)
            return fragment
        end
    end
    # If not using fragments, replace node
    minsize = rules_minsize(grammar)
    possible_rules = filter(r -> minsize[r] ≤ max_size, grammar[type])
    if isempty(possible_rules)
        return nothing
    end
    rule_index = StatsBase.sample(possible_rules)
    rule_node = RuleNode(rule_index)

    if !grammar.isterminal[rule_index]
        symbol_minsize = symbols_minsize(grammar, minsize)
        sizes = random_partition(grammar, rule_index, max_size, symbol_minsize)

        for (index, child_type) in enumerate(child_types(grammar, rule_index))
            push!(rule_node.children, generate_random_program(grammar, child_type, fragments, config, generate_with_angelic, sizes[index], disabled_fragments))
        end
    end

    rule_node
end

"""
    random_modify_children!(grammar::AbstractGrammar, node::RuleNode, config::FrAngelConfig, generate_with_angelic::Bool)

Randomly modifies the children of a given node. The modification can be either a new random program or a modification of the existing children.

# Arguments
- `grammar`: An abstract grammar object.
- `node`: The node to modify the children of.
- `config`: A FrAngelConfig object containing the configuration for the random modification.
- `generate_with_angelic`: A boolean flag to enable the use of angelic conditions in the program generation.

# Returns
Modifies the `node` directly.
"""
function random_modify_children!(grammar::AbstractGrammar, node::RuleNode, config::FrAngelConfig, generate_with_angelic::Float16)
    for (index, child) in enumerate(node.children)
        if rand() < config.gen_similar_prob_new
            node.children[index] = generate_random_program(grammar, return_type(grammar, child), Set{RuleNode}(), config, generate_with_angelic, count_nodes(grammar, child) + config.similar_new_extra_size, true)
        else
            random_modify_children!(grammar, child, config, generate_with_angelic)
        end
    end
end

"""
    get_replacements(node::RuleNode, grammar::AbstractGrammar)::AbstractVector{RuleNode}

Finds all the possible replacements for a given node in the AST. 
Looks for single-node trees corresponding to all variables and constants in the grammar, and node descendants of the same symbol.

# Arguments
- `node`: The node to find replacements for.
- `grammar`: An abstract grammar object.

# Returns
A vector of RuleNodes representing all the possible replacements for the provided node, ordered by size.
"""
function get_replacements(node::RuleNode, grammar::AbstractGrammar)::AbstractVector{RuleNode}
    replacements = Set{RuleNode}([])
    symbol = return_type(grammar, node)

    # The empty tree, if N⊤ is a statement in a block.
    children_types = child_types(grammar, node.ind)

    for rule_index in eachindex(grammar.rules)
        if grammar.types[rule_index] == symbol && length(child_types(grammar, rule_index)) < length(children_types)
            possible_replacement = RuleNode(rule_index)

            # TODO: possibly update it, to work regardless of the order
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

    # Single-node trees corresponding to all variables and constants in the grammar.
    for rule_index in eachindex(grammar.rules)
        if isterminal(grammar, rule_index) && return_type(grammar, rule_index) == symbol
            push!(replacements, RuleNode(rule_index))
        end
    end

    # D⊤ for all descendant nodes D of N.
    get_descendant_replacements!(node, symbol, grammar, replacements)

    # Order by replacement size
    sort!(collect(replacements), by=x -> count_nodes(grammar, x))
end

"""
    get_descendant_replacements!(node::RuleNode, symbol::Symbol, grammar::AbstractGrammar, replacements::AbstractSet{RuleNode})

Finds all the descendants of the same symbol for a given node in the AST.

# Arguments
- `node`: The node to find descendants in.
- `symbol`: The symbol to find descendants for.
- `grammar`: An abstract grammar object.
- `replacements`: A set of RuleNodes to add the descendants to.

# Returns
Updates the `replacements` set with all the descendants of the same symbol for the provided node.
"""
function get_descendant_replacements!(node::RuleNode, symbol::Symbol, grammar::AbstractGrammar, replacements::AbstractSet{RuleNode})
    for child in node.children
        if return_type(grammar, child) == symbol
            push!(replacements, deepcopy(child))
        end
        get_descendant_replacements!(child, symbol, grammar, replacements)
    end
end