"""
    buildProgrammingProblemGrammar(input_parameters::AbstractVector{Tuple{Symbol,Symbol}}, return_type::Symbol, intermediate_variables_count::Int=0)::ContextSensitiveGrammar

Builds a context-sensitive grammar for a generalized programming problem that FrAngel can use.

# Arguments
- `input_parameters`: An abstract vector of tuples representing the input parameters of the problem. 
Each tuple consists of a symbol representing the parameter name and a symbol representing the parameter type.
- `return_type`: A symbol representing the return type of the problem.
- `intermediate_variables_count`: An optional integer representing the number of intermediate variables to be used in the problem. Default is 0.

# Returns
A `ContextSensitiveGrammar` object representing the grammar for the programming problem.

"""
function buildProgrammingProblemGrammar(
    input_parameters::AbstractVector{Tuple{Symbol,Symbol}},
    return_type::Symbol,
    intermediate_variables_count::Int=0
)::ContextSensitiveGrammar
    base = deepcopy(@cfgrammar begin
        Program = (VariableDefintion; Statement; Return) | (Statement; Return) | Return
        VariableDefintion = ListVariable = List

        Statement = (Statement; Statement)
        Statement = (
            i = 0;
            while Bool
                InnerStatement
                i = i + 1
            end)
        Statement = (
            if Bool
                Statement
            end
        )
        Statement = push!(ListVariable, Num)

        InnerNum = Num | i | (InnerNum + InnerNum) | (InnerNum - InnerNum)
        InnerStatement = push!(ListVariable, InnerNum)

        Num = |(0:9) | (Num + Num) | (Num - Num)
        Num = getindex(ListVariable, Num)

        Bool = true | false | (InnerNum < InnerNum)

        List = [] | ListVariable

        ListVariable = list
    end)
    # Add input variables
    for input_parameter in input_parameters
        add_rule!(base, :($(input_parameter[2]) = $(input_parameter[1])))
    end
    #TODO: Add intermediate variables

    # Add return statement
    add_rule!(base, :(Return = return $return_type))
    base
end

"""
    print_grammar(g::AbstractGrammar)

Pretty-prints a probabilistic grammar. 
For example, a rule with probability 0.5 and format Num = Num + Num is printed as: "0.5  1: Num = Num + Num"

# Arguments
- `g`: The grammar to be printed.

"""
function print_grammar(g::AbstractGrammar)
    for i in eachindex(g.rules)
        println(g.log_probabilities[i], "  ", i, ": ", g.types[i], " = ", g.rules[i])
    end
end

"""
    add_fragments_prob!(grammar::AbstractGrammar, fragments_chance::Float16, fragment_base_rules_offset::Int16, fragment_rules_offset::Int16)

Adds the probabilities of using fragment rules to the grammar. For a fragment rule to be found it should be named `Fragment_<symbol>`.
It should be a terminal rule and have the same type as the symbol it is a fragment of. There should be at most one fragment rule for each symbol.
The grammar is updated in-place.
        
# Arguments
- `grammar`: The grammar rules of the program. Updates its probabilities directly.
- `fragments_chance`: The probability of using a fragment rule.
- `fragment_base_rules_offset`: The offset for fragment base/identity rules.
- `fragment_rules_offset`: The offset for fragment rules.

"""
function add_fragments_prob!(grammar::AbstractGrammar, fragments_chance::Float16, fragment_base_rules_offset::Int16, fragment_rules_offset::Int16)
    if isnothing(grammar.log_probabilities)
        grammar.log_probabilities = fill(Float16(1), length(grammar.rules))
    else
        resize!(grammar.log_probabilities, length(grammar.rules))
    end

    for i in fragment_base_rules_offset+1:fragment_rules_offset
        if isterminal(grammar, i)
            if grammar.log_probabilities[i] != Float16(0)
                grammar.log_probabilities[i] = Float16(0)
                others_prob = Float16(1) / (length(grammar.bytype[grammar.types[i]]) - 1)
                for j in grammar.bytype[return_type(grammar, i)]
                    if j != i
                        grammar.log_probabilities[j] = others_prob
                    end
                end
            end
        else
            if grammar.log_probabilities[i] != fragments_chance
                grammar.log_probabilities[i] = fragments_chance
                others_prob = Float16(1 - fragments_chance) / (length(grammar.bytype[grammar.types[i]]) - 1)
                for j in grammar.bytype[return_type(grammar, i)]
                    if j != i
                        grammar.log_probabilities[j] = others_prob
                    end
                end
            end

            fragments_prob = Float16(1) / length(grammar.bytype[grammar.rules[i]])
            for j in grammar.bytype[grammar.rules[i]]
                grammar.log_probabilities[j] = fragments_prob
            end
        end
    end
end


"""
    setup_grammar_with_fragments(grammar::AbstractGrammar, use_fragments_chance::Float16, rule_minsize::AbstractVector{UInt8})

Sets up the grammar with fragments by adding fragment base/identity rules (eg. `<symbol> = Fragment_<symbol>`), resizes the rule minimum size, and adds fragment probabilities.
The grammar is updated in-place.

# Arguments
- `grammar`: The grammar object to set up.
- `use_fragments_chance`: The chance of using fragments.
- `rule_minsize`: The minimum size of each rule.

# Returns
A tuple `(fragment_base_rules_offset, fragment_rules_offset)` representing the offsets of fragments base rules (i.e. the start and end indices of the fragments base rules).
The latter is also the starting index of the regular fragment rules (`Fragment_<symbol> = <expression>`)

"""
function setup_grammar_with_fragments!(grammar::AbstractGrammar, use_fragments_chance::Float16, rule_minsize::AbstractVector{UInt8})::Tuple{Int16,Int16}
    # Add identity fragment rules
    fragment_base_rules_offset::Int16 = length(grammar.rules)
    add_fragment_base_rules!(grammar)
    fragment_rules_offset::Int16 = length(grammar.rules)

    # Resize rule_minsize
    resize!(rule_minsize, fragment_rules_offset)
    for i in fragment_base_rules_offset+1:fragment_rules_offset
        rule_minsize[i] = 255
    end

    # Add probabilities of identity fragment rules based on config
    add_fragments_prob!(grammar, use_fragments_chance, fragment_base_rules_offset, fragment_rules_offset)
    return (fragment_base_rules_offset, fragment_rules_offset)
end

"""
    add_fragment_base_rules!(g::AbstractGrammar)

Adds base/identity rules for fragments to the given grammar. The grammar is updated in-place.

# Arguments
- `g`: The grammar to add the rules to.

"""
function add_fragment_base_rules!(g::AbstractGrammar)
    # Add base/identity rule to each type
    for typ in keys(g.bytype)
        # Skip angelic rulenode - cannot have fragments
        if typ == :Angelic
            continue
        end
        # Create rule
        expr = Symbol(string(:Fragment_, typ))
        rvec = Any[]
        parse_rule!(rvec, expr)
        for r ∈ rvec
            # Add rule unless there exists an identity fragment rule already
            if !any(r === rule && typ === return_type(g, i) for (i, rule) ∈ enumerate(g.rules))
                push!(g.rules, r)
                push!(g.iseval, iseval(expr))
                push!(g.types, typ)
                g.bytype[typ] = push!(get(g.bytype, typ, Int[]), length(g.rules))
            end
        end
    end
    # Update supplemental data structures in bulk
    alltypes = collect(keys(g.bytype))
    g.isterminal = [isterminal(rule, alltypes) for rule ∈ g.rules]
    g.childtypes = [get_childtypes(rule, alltypes) for rule ∈ g.rules]
    g.bychildtypes = [BitVector([g.childtypes[i1] == g.childtypes[i2] for i2 ∈ 1:length(g.rules)]) for i1 ∈ 1:length(g.rules)]
    g.domains = Dict(type => BitArray(r ∈ g.bytype[type] for r ∈ 1:length(g.rules)) for type ∈ keys(g.bytype))
end

"""
    add_fragment_rules!(g::AbstractGrammar, fragments::AbstractVector{RuleNode})

Adds fragment rules to the given grammar. A fragment rule has the form `Fragment_<symbol> = <expression>`.
The expressions are taken from the fragments. The grammar is updated in-place.

# Arguments
- `g`: The grammar to add the rules to.
- `fragments`: A vector of fragment to add as rules.

"""
function add_fragment_rules!(g::AbstractGrammar, fragments::AbstractVector{RuleNode})
    # Add each fragment
    for fragment in fragments
        # Create rule
        typ = Symbol("Fragment_", return_type(g, fragment))
        expr = rulenode2expr(fragment, g)
        rvec = Any[]
        parse_rule!(rvec, expr)
        for r ∈ rvec
            # Add rule unless expression was already added (should never happen as fragments are stored in a set, but just in case)
            if !any(r === rule && typ === return_type(g, i) for (i, rule) ∈ enumerate(g.rules))
                push!(g.rules, r)
                push!(g.iseval, iseval(expr))
                push!(g.types, typ)
                g.bytype[typ] = push!(get(g.bytype, typ, Int[]), length(g.rules))
            end
        end
    end
    # Update supplemental data structures in bulk
    alltypes = collect(keys(g.bytype))
    g.isterminal = [isterminal(rule, alltypes) for rule ∈ g.rules]
    g.childtypes = [get_childtypes(rule, alltypes) for rule ∈ g.rules]
    g.bychildtypes = [BitVector([g.childtypes[i1] == g.childtypes[i2] for i2 ∈ 1:length(g.rules)]) for i1 ∈ 1:length(g.rules)]
    g.domains = Dict(type => BitArray(r ∈ g.bytype[type] for r ∈ 1:length(g.rules)) for type ∈ keys(g.bytype))
end