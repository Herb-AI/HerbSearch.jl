module RefactorExt

using HerbCore, HerbGrammar, HerbSearch, Clingo_jll

include("enumerate_subtrees.jl")
include("parsing_IO.jl")
include("analyze_compressions.jl")
include("extend_grammar.jl")

"""
    refactor_grammar(trees::Vector{RuleNode}, grammar::AbstractGrammar, subtree_selection_strategy::Int, f_best::Float64)

Optimises a grammar based on a set of trees ([`RuleNode`](@ref)s).

The algorithm works in five stages: 
1. For each tree and all sub-trees are enumerated and a selection of subtrees is made.
2. The selected subtrees are parsed to JSON and passed to clingo.
3. Clingo is called to find the best compressions. 
4. Read Clingo output is read to JSON
5. The compressions are parsed and analysed, some of these compressions are chosen to extend the grammar. This extended grammar is returned.

# Arguments
- `trees::AbstractVector{RuleNode}`: the trees to optimise the grammar for
- `grammar::AbstractGrammar`: the grammar to optimise
- `subtree_selection_strategy::SelectionStrategy`: the strategy to select subtrees, strategy 1 is based on occurrences and strategy 2 is based on size * occurrences
- `f_best::Float64`: the number of best compressions to select

# Returns
- `new_grammar::AbstractGrammar`: the optimised grammar
"""
#=
function HerbSearch.old_refactor_grammar(trees::AbstractVector{RuleNode}, grammar::AbstractGrammar, subtree_selection_strategy::SelectionStrategy, f_best::Float64)
    start_time = time()
    @debug "Stage 1: Enumerate subtrees and discard useless subtrees"
    subtree_set = Vector{Any}()
    for tree in trees
        subtrees = enumerate_subtrees(tree, grammar)
        subtrees = filter(subtree -> selection_criteria(tree, subtree), subtrees) #remove subtrees size 1 and treesize
        subtree_set = vcat(subtree_set, subtrees)
    end
    @debug "Time for stage 1: $(time() - start_time)"
    start_time = time()
    subtree_set = unique(subtree_set)
    
    @debug "Stage 2: parse subtrees to json"
    data = []
    for tree in trees
        push!(data, convert_subtrees_to_json(subtree_set, tree))
    end
    global_dicts = []
    for i in 1:length(trees)
        model, global_dict = parse_json(data[i])
        data[i] = model
        push!(global_dicts, global_dict)
    end
    @debug "Time for stage 2 : $(time() - start_time)"
    start_time = time()
    
    println(data[1])

    @debug "Stage 3: call clingo"
    dir_path = dirname(@__FILE__)     
    model_location = joinpath(dir_path, "model.lp")
    for i in 1:length(trees)
        command = `$(clingo()) $(model_location) - --outf=2`
        output = IOBuffer()
        run(pipeline(ignorestatus(command), stdin=IOBuffer(data[i]), stdout=output))
        data[i] = String(take!(output))
    end
    @debug "Time for stage 3 : " * string(time() - start_time)
    start_time = time()
    
    @debug "Stage 4: Read clingo output to json"     
    best_values = []
    for i in 1:length(trees)
        push!(best_values, read_last_witness_from_json(data[i]))
    end
    @debug "Time for stage 4 : " * string(time() - start_time)
    start_time = time()

    @debug "Stage 5: Analyze clingo output"
    all_stats = Vector{Dict{RuleNode, NamedTuple{(:size,:occurrences), <:Tuple{Int64,Int64}}}}()
    for i in 1:length(trees)
        node_assignments::Vector{String} = best_values[i]

        stats = generate_stats(global_dicts[i], node_assignments)

        stats = generate_trees_from_compressions(global_dicts[i], stats, grammar)

        push!(all_stats, stats)
    end

    println(best_values[1])
    println(all_stats[1])

    combined_stats = zip_stats(all_stats)
    best_compressions = select_compressions(subtree_selection_strategy, combined_stats, f_best)
    new_grammar = deepcopy(grammar)

    for b in best_compressions
        add_rule!(new_grammar, b)
    end
    @debug "Time for stage 5 : " * string(time() - start_time)
    start_time = time()
    return new_grammar
end
=#

function HerbSearch.refactor_grammar(trees::AbstractVector{RuleNode}, grammar::AbstractGrammar)
    start_time = time()
    @debug "Stage 1: Enumerate subtrees and discard useless subtrees"
    subtree_set = Vector{Any}()
    for tree in trees
        subtrees = enumerate_subtrees(tree, grammar)
        subtrees = filter(subtree -> selection_criteria(tree, subtree), subtrees) #remove subtrees size 1
        subtree_set = vcat(subtree_set, subtrees)
    end
    subtree_set = unique(subtree_set)
    @debug "Time for stage 1: $(time() - start_time)"

    #println(subtree_set)


    start_time = time()
    @debug "Stage 2: parse subtrees to json"
    data = convert_to_json(subtree_set, trees)
    model, global_dict = parse_json(data)
    @debug "Time for stage 2 : $(time() - start_time)"
    start_time = time()

    #println(trees)
    #println(data)

    #println(first(model, 2000))

    @debug "Stage 3: call clingo"
    dir_path = dirname(@__FILE__)     
    model_location = joinpath(dir_path, "model.lp")
    command = `$(clingo()) $(model_location) - --outf=2`
    output = IOBuffer()
    run(pipeline(ignorestatus(command), stdin=IOBuffer(model), stdout=output))
    data = String(take!(output))
    @debug "Time for stage 3 : " * string(time() - start_time)


    #println(model)
    println(data)

    @debug "Stage 4: Read clingo output to json"     
    best_values = read_last_witness_from_json(data)
    @debug "Time for stage 4 : " * string(time() - start_time)
    start_time = time()

    node_assignments::Vector{String} = best_values
    stats = generate_stats(global_dict, node_assignments)
    best_compressions = generate_trees_from_compressions(global_dict, stats, grammar)

    println(best_compressions)

    new_grammar = deepcopy(grammar)

    for new_rule in best_compressions
        add_rule!(new_grammar, new_rule)
    end

    return new_grammar
end

end