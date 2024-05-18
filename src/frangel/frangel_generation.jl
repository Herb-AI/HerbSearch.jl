"""
    generate_random_program(grammar::AbstractGrammar, type::Symbol, fragments::Set{RuleNode}, config::FrAngelConfigGeneration, generate_with_angelic::Float16, 
        angelic_conditions::AbstractVector{Union{Nothing,Int}}, max_size, disabled_fragments=false)::Union{RuleNode, Nothing}

Generates a random program of the provided `type` using the provided `grammar`. The program is generated with a maximum size of `max_size` and can use fragments from the provided set.

# Arguments
- `grammar`: The grammar rules of the program.
- `type`: The type of the program to generate.
- `fragments`: A set of RuleNodes representing the fragments that can be used in the program generation.
- `config`: The configuration for program generation of FrAngel.
- `generate_with_angelic`: A float representing the chance to generate a program with an angelic condition. Set to 0 if no such conditions are desired.
- `angelic_conditions`: A vector of integers representing the index of the child to replace with an angelic condition for each rule. 
    If there is no angelic condition for a rule, the value is set to `nothing`.
- `max_size`: The maximum size of the program to generate.
- `disabled_fragments`: A boolean flag to disable the use of fragments in the program generation.

# Note
The values passed as `max_size` and `generate_with_angelic` to the function will be used over the `config` values.

# Returns
A random program of the provided type, or nothing if no program can be generated.

"""
function generate_random_program(
    grammar::AbstractGrammar,
    type::Symbol,
    config::FrAngelConfigGeneration,
    fragments_offset::Number,
    max_size,
    rule_minsize::AbstractVector{Int},
    symbol_minsize::Dict{Symbol,Int}
)::Union{RuleNode,Nothing}
    if max_size < 0
        return nothing
    end
    
    possible_rules = filter(r -> r <= fragments_offset && rule_minsize[r] ≤ max_size, grammar[type])
    if isempty(possible_rules)
        return nothing
    end
    rule_index = StatsBase.sample(possible_rules)
    rule_node = RuleNode(rule_index)

    if !grammar.isterminal[rule_index]
        sizes = random_partition(grammar, rule_index, max_size, symbol_minsize)

        for (index, child_type) in enumerate(child_types(grammar, rule_index))
            push!(rule_node.children, generate_random_program(grammar, child_type, config, fragments_offset, sizes[index], rule_minsize, symbol_minsize))
        end
    end

    rule_node
end

function modify_and_replace_program_fragments!(
    program::RuleNode, 
    fragments::AbstractVector{RuleNode}, 
    fragments_offset::Number, 
    config::FrAngelConfigGeneration,
    grammar::AbstractGrammar, 
    rule_minsize::AbstractVector{Int},
    symbol_minsize::Dict{Symbol,Int}
)::RuleNode 
    if is_fragment_rule(grammar, program.ind)
        fragment_rule_index = program.children[1].ind
        # a fragment was found

        if rand() < config.use_entire_fragment_chance
            # use fragment as is
            return fragments[fragment_rule_index - fragments_offset]
        else
            # modify the fragment
            modified_fragment = deepcopy(fragments[fragment_rule_index - fragments_offset])
            random_modify_children!(grammar, modified_fragment, config, fragments_offset, rule_minsize, symbol_minsize)
            return modified_fragment
        end
    else
        # traverse the tree to find fragments to replace
        if isterminal(grammar, program.ind)
            return program
        end

        for (index, child) in enumerate(program.children)
            program.children[index] = modify_and_replace_program_fragments!(child, fragments, fragments_offset, config, grammar, rule_minsize, symbol_minsize)
        end

        program
    end
end

"""
    random_modify_children!(grammar::AbstractGrammar, node::RuleNode, config::FrAngelConfigGeneration, generate_with_angelic::Float16, 
        angelic_conditions::AbstractVector{Union{Nothing,Int}})

Randomly modifies the children of a given node. The modification can be either a new random program or a modification of the existing children.

# Arguments
- `grammar`: The grammar rules of the program.
- `node`: The node to modify the children of.
- `config`: The configuration for program generation of FrAngel.
- `generate_with_angelic`: A float representing the chance to generate a program with an angelic condition.
- `angelic_conditions`: A vector of integers representing the index of the child to replace with an angelic condition for each rule. 
    If there is no angelic condition for a rule, the value is set to `nothing`.

# Returns
Modifies the `node` directly.

"""
function random_modify_children!(
    grammar::AbstractGrammar,
    node::RuleNode,
    config::FrAngelConfigGeneration,
    fragments_offset::Number,
    rule_minsize::AbstractVector{Int},
    symbol_minsize::Dict{Symbol,Int}
)::Nothing
    for (index, child) in enumerate(node.children)
        if rand() < config.gen_similar_prob_new
            node.children[index] = generate_random_program(grammar, return_type(grammar, child), config, fragments_offset, count_nodes(grammar, child) + config.similar_new_extra_size, rule_minsize, symbol_minsize)
        else
            random_modify_children!(grammar, child, config, fragments_offset, rule_minsize, symbol_minsize)
        end
    end
end

"""
    get_replacements(node::RuleNode, grammar::AbstractGrammar)::AbstractVector{RuleNode}

Finds all the possible replacements for a given node in the AST. 
Looks for single-node trees corresponding to all variables and constants in the grammar, and node descendants of the same symbol.

# Arguments
- `node`: The node to find replacements for.
- `grammar`: The grammar rules of the program.

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
- `grammar`: The grammar rules of the program.
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

function add_angelic_conditions!(program::RuleNode, grammar::AbstractGrammar, angelic_conditions::AbstractVector{Union{Nothing,Int}}, config::FrAngelConfigGeneration) 
    if isterminal(grammar, program.ind)
        return program
    end

    if angelic_conditions[program.ind] !== nothing && rand() < config.use_angelic_conditions_chance
        angelic_condition_ind = angelic_conditions[program.ind]

        for (index, child) in enumerate(program.children)
            if index != angelic_condition_ind
                program.children[index] = add_angelic_conditions!(child, grammar, angelic_conditions, config)
            end
        end

        program.children[angelic_condition_ind] = Hole(grammar.domains[return_type(grammar, program.ind)])
    else
        for (index, child) in enumerate(program.children)
            program.children[index] = add_angelic_conditions!(child, grammar, angelic_conditions, config)
        end
    end
    
    program
end