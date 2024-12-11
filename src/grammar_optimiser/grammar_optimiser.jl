using Clingo_jll
include("enumerate_subtrees.jl")
include("parsing_IO.jl")
include("analyze_compressions.jl")
include("extend_grammar.jl")

"""
    grammar_optimiser(trees::Vector{RuleNode}, grammar::AbstractGrammar, subtree_selection_strategy::Int, f_best::Float64, verbosity=0:Int)

Optimises a grammar based on a set of trees. The algorithm works in three stages: 
1. The subtrees are enumerated, parsed to JSON and passed to clingo.
2. Clingo is called to find the best compressions. 
3. The compressions are parsed and analysed, some of these compressions are chosen to extend the grammar. This extended grammar is returned.
# Arguments
- `trees::Vector{RuleNode}`: the trees to optimise the grammar for
- `grammar::AbstractGrammar`: the grammar to optimise
- `subtree_selection_strategy::Int`: the strategy to select subtrees, strategy 1 is based on occurrences and strategy 2 is based on size * occurrences
- `f_best::Float64`: the number of best compressions to select
- `verbosity::Int`: the verbosity level
# Result
- `new_grammar::AbstractGrammar`: the optimised grammar
"""
function grammar_optimiser(trees::Vector{RuleNode}, grammar::AbstractGrammar, subtree_selection_strategy::Int, f_best::Float64, verbosity=0:Int)
    # 1. Enumerate subtrees 
    start_time = time()
    verbosity > 0 && print("Stage 1: Select subtrees\n")     
    subtree_set = Vector{Any}()
    for tree in trees
        subtrees = enumerate_subtrees(tree, grammar)
        subtrees = filter(subtree -> selection_criteria(tree, subtree), subtrees) #remove subtrees size 1 and treesize
        subtree_set = vcat(subtree_set, subtrees)
    end
    verbosity > 1 && print("Time for stage 1: " * string(time() - start_time) * "\n"); start_time = time()
    subtree_set = unique(subtree_set)
    
    # 2. Parse subtrees to json
    verbosity > 0 && print("Stage 2: parse subtrees to json\n")     
    data = []
    for tree in trees
        push!(data, parse_subtrees_to_json(subtree_set, tree))
    end
    global_dicts = []
    for i in 1:length(trees)
        model, global_dict = parse_json(data[i])
        data[i] = model
        push!(global_dicts, global_dict)
    end
    verbosity > 1 && print("Time for stage 2 : " * string(time() - start_time) * "\n"); start_time = time()
    
    # 3. Call clingo 
    verbosity > 0 && print("Stage 3: call clingo\n")
    dir_path = dirname(@__FILE__)     
    model_location = joinpath(dir_path, "model.lp")
    for i in 1:length(trees)
        command = `$(clingo()) $(model_location) - --outf=2`
        output = IOBuffer()
        run(pipeline(ignorestatus(command), stdin=IOBuffer(data[i]), stdout=output))
        data[i] = String(take!(output))
    end
    verbosity > 1 && print("Time for stage 3 : " * string(time() - start_time) * "\n"); start_time = time()
    
    # 4. Parse clingo output to json
    verbosity > 0 && print("Stage 4: Parse clingo output to json\n")     
    best_values = []
    for i in 1:length(trees)
        push!(best_values, read_json(data[i]))
    end
    verbosity > 1 && print("Time for stage 4 : " * string(time() - start_time) * "\n"); start_time = time()

    # 5. Analyse clingo output
    verbosity > 0 && print("Stage 5: Analyze subtrees\n") # 5. Analyse clingo output
    all_stats = Vector{Dict{RuleNode, NamedTuple{(:size,:occurrences), <:Tuple{Int64,Int64}}}}()
    for i in 1:length(trees)
        node_assignments::Vector{String} = best_values[i]

        stats = generate_stats(global_dicts[i], node_assignments)

        stats = generate_trees_from_compressions(global_dicts[i], stats, grammar)

        push!(all_stats, stats)
    end

    combined_stats = zip_stats(all_stats)
    best_compressions = select_compressions(subtree_selection_strategy, combined_stats, f_best; verbosity)
    new_grammar = grammar

    for b in best_compressions
        add_rule!(new_grammar, b)
    end
    verbosity > 1 && print("Time for stage 5 : " * string(time() - start_time) * "\n"); start_time = time()
    return new_grammar
end



