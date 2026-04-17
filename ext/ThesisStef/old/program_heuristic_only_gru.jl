using HerbBenchmarks, HerbSearch, HerbConstraints, HerbCore, HerbGrammar
using Flux, Random, Statistics, JLD2, Dates, Base.Threads

include("string_grammar.jl")
include("best_first_string_iterator.jl")
include("known_heuristics.jl")

# -------------------
# 1. Data
# -------------------

function generate_triplets_4(;
    amount_of_programs,
    max_depth,
    problem_id,
    example_ids,
)
    benchmark       = HerbBenchmarks.String_transformations_2020
    problem_grammar = get_all_problem_grammar_pairs(benchmark)[problem_id]
    problem         = problem_grammar.problem
    spec            = problem.spec[example_ids]
    start_states    = [example.in[:_arg_1] for example in spec]
    final_states    = [example.out for example in spec]
    iterator        = HerbSearch.BFSIterator(grammar, :Program, max_depth=max_depth)

    function interpret_program(program)
        try
            return [benchmark.interpret(program, benchmark.get_relevant_tags(grammar), example.in[:_arg_1]) for example in spec]
        catch e
            if typeof(e) == BoundsError
                return nothing
            else
                rethrow(e)
            end
        end
    end

    function get_parents(program)
        i = program.ind
        c = program.children

        if i == 1
            return [nothing]
        elseif i == 2
            return [c[1], RuleNode(1, [c[2]])]
        elseif i == 8
            return c[2:3]
        elseif i == 9
            return c[2:2]
        end
    end

    @show [s.str for s in start_states]
    @show [s.str for s in final_states]
    println("\nGenerating triplets")

    program_to_state = Dict("nothing" => start_states)
    shortest_paths = Dict((start_states, start_states) => 0)

    for (i, program) in enumerate(iterator)
        states = interpret_program(program)

        if isnothing(states)
            continue
        end

        program_to_state["$program"] = states

        if !haskey(shortest_paths, (states, states))
            shortest_paths[(states, states)] = 0
        end

        for parent in get_parents(program)
            if !haskey(program_to_state, "$parent")
                continue
            end

            parent_states = program_to_state["$parent"]

            for ((states_in, states_out), size) in shortest_paths
                if states_out == parent_states && !haskey(shortest_paths, (states_in, states))
                    shortest_paths[(states_in, states)] = size + 1
                end
            end
        end

        if i >= amount_of_programs
            break
        end
    end

    states = collect(Set(values(program_to_state)))
    triplets_anp = []
    equal_inputs = 0
    equal_outputs = 0

    # for ((states_1, states_2), size) in shortest_paths
    #     if !haskey(shortest_paths, (states_2, states_1)) #&& size < 4
    #         shortest_paths[(states_2, states_1)] = 1000
    #     end
    # end

    for ((state_in_1, state_out_1), size_1) in shortest_paths
        for ((state_in_2, state_out_2), size_2) in shortest_paths
            # if size_1 < size_2
            if size_1 == 1 && size_2 > 1
                # e_in_1 = encode_state.(state_in_1)
                # e_out_1 = encode_state.(state_out_1)
                # e_in_2 = encode_state.(state_in_2)
                # e_out_2 = encode_state.(state_out_2)

                # Case 1: equal inputs
                if state_in_1 == state_in_2
                    push!(triplets_anp, (state_in_1, state_out_1, state_out_2))
                    # push!(triplets_anp, (e_in_1, e_out_1, e_out_2))
                    equal_inputs += 1
                end

                # Case 2: equal outputs
                if state_out_1 == state_out_2
                    push!(triplets_anp, (state_out_1, state_in_1, state_in_2))
                    # push!(triplets_anp, (e_out_1, e_in_1, e_in_2))
                    equal_outputs += 1
                end
            end
        end
    end

    println("\nVisited $(length(Set(values(program_to_state)))) states")
    println("Created $(length(shortest_paths)) paths")
    @show equal_inputs
    @show equal_outputs

    return triplets_anp
end


# -------------------
# 2. Encoding
# -------------------

function encode_state(state; use_pointer=true)
    if state isa String
        s = state
    else
        s = state.str
    end

    idxs = [1 + Int(c) for c in collect(s)]
    
    # if length(idxs) > 0
    #     if !isnothing(state.pointer) && use_pointer
    #         idxs[state.pointer] += 1
    #     end
    # end

    if isempty(idxs)
        idxs = [1]
    end

    return idxs

    # function encode_symbol(b, i)
    #     if i == state.pointer && use_pointer
    #         return digits(2*Int(b)+1, base=2, pad=8)
    #     end

    #     return digits(2*Int(b), base=2, pad=8)
    # end

    # if length(s) == 0
    #     return tuple([[0,0,0,0,0,0,0,0]]...)
    # else
    #     return tuple([encode_symbol(b, i) for (b, i) in enumerate(codeunits(s))]...)
    # end
end


# -------------------
# 3. Model
# -------------------

function custom_distance(e1, e2)
    # if e1[1] - e2[1] > 0.01
    #     return sum((e1 - e2).^2) + (e1[1] - e2[1] - 0.01) * 100
    # else
    #     return sum((e1 - e2).^2)
    # end

    return sum((e1 - e2).^2)
end

function get_distances_model(;triplets, embed_dim, hidden_dim, learning_rate)
    model = Chain(
        Embedding(2^7 => embed_dim),
        # Parallel(hcat, Dense(8 => embed_dim)),
        GRU(embed_dim => hidden_dim),
        Dense(hidden_dim => 2 * hidden_dim),
        Dense(2 * hidden_dim => hidden_dim),
        x -> x[:, end],
    )

    # function loss_triplet_alignment(model, anchors, positives, negatives)
    function loss_triplet_alignment(model, anchors, positives, negatives)
        e_anchors   = model.(encode_state.(anchors))
        e_positives = model.(encode_state.(positives))
        e_negatives = model.(encode_state.(negatives))
        # e_anchors   = model.(anchors)
        # e_positives = model.(positives)
        # e_negatives = model.(negatives)

        function triplet_loss(z1, z2, z3; margin=.1)
            d_positive = custom_distance(z1, z2)
            d_negative = custom_distance(z1, z3)

            return max(0, d_positive - d_negative + margin)
        end
        
        function variance_loss(zs)
            m = mean(zs, dims=1)

            function single_loss(z)
                return sum((z - m[1]).^2)
            end

            return mean(single_loss.(zs))
        end

        pen_l2(x::AbstractArray) = sum(abs2, x)/2

        triplet = mean(triplet_loss.(e_anchors, e_positives, e_negatives))
        align = variance_loss(e_anchors) + variance_loss(e_positives) + variance_loss(e_negatives)
        penalty = sum(pen_l2, Flux.trainables(model))

        return triplet #+ penalty #+ align
    end

    # println("Training model")
    shuffle!(triplets)
    opt_state = Flux.setup(RMSProp(eta=learning_rate), model)
    Flux.train!(loss_triplet_alignment, model, triplets, opt_state)
    # println("Model trained")

    return model
end

# -------------------
# 4. Test
# -------------------

function model_heuristic(model, input_states, output_states)
    if input_states == output_states
        return 0
    end

    e_ins  = model.(encode_state.(input_states))
    e_outs = model.(encode_state.(output_states))
    return mean(custom_distance.(e_ins, e_outs))

    # return mean(model.(zip(e_ins, e_outs)))
end

function training_accuracy(model, triplets)
    println("\nTesting model")
    score = 0
    total = 0

    for (as, ps, ns) in triplets
        total += 1

        e_as = model.(encode_state.(as))
        e_ps = model.(encode_state.(ps))
        e_ns = model.(encode_state.(ns))
        d_ap = mean(custom_distance.(e_as, e_ps))
        d_an = mean(custom_distance.(e_as, e_ns))

        if d_ap < d_an
            score += 1
        end
    end

    acc = score / total
    accr = round(acc, digits=2)
    println("Accuracy: $accr")

    return acc
end

function show_ordering(model, output_string, input_strings)
    function sort_input_states(model, input_states, output_state)
        d(input_state) = model_heuristic(model, [input_state], [output_state])
        sort!(input_states, by = d)

        return input_states
    end

    println("")
    output_state = HerbBenchmarks.String_transformations_2020.StringState(output_string, length(output_string))
    input_states = [HerbBenchmarks.String_transformations_2020.StringState(str, 1) for str in input_strings]
    sort_input_states(model, input_states, output_state)

    for input_state in input_states
        v = model_heuristic(model, [input_state], [output_state])
        println(round(v, digits = 4), "\t", input_state.pointer, "\t", input_state.str)
    end
end

function test_best_first_iterator(; model, use_levenshtein, max_iterations, max_size, problem_id, example_ids)
    heuristic(iter, program, states) = use_levenshtein ? 
        levenshtein_heuristic(states, iter.final_states) :
        model_heuristic(model, states, iter.final_states)

    # heuristic(iter, program, states) = length(program) 

    function state_to_str(state)
        return "$(state.str) | $(state.pointer)"
    end

    iter = BestFirstStringIterator(heuristic, max_size, true, problem_id, example_ids)


    for (i, entry) in enumerate(iter)
        println()
        @show i
        @show entry.program
        @show state_to_str.(entry.states)
        @show entry.cost

        if [s.str for s in entry.states] == [s.str for s in iter.final_states]
            # println("\n\n\n")
            # println("Found: $(entry.program)")
            # println("Took $i iterations")
            return i
            break
        end

        if i == max_iterations
            return i
            break
        end

        i += 1
    end
end

function execute_experiment(;
    experiment_name,
    filename,
    repetitions = 10,
    problem_ids = 1:100,
    example_ids = 1:5,
    amount_of_programs_exploration = 70,
    max_depth_exploration = 7,
    learning_rate = 0.04,
    amount_of_programs_explotation = 200,
    max_size_explotation = 10,
    model = "Embed -> GRU",
    embed_dim = 8,
    hidden_dim = 8,
)
    data = Dict(
        "timestamp" => now(),
        "experiment_name" => experiment_name,
        "repetitions" => repetitions,
        "problem_ids" => problem_ids,
        "example_ids" => example_ids,
        "amount_of_programs_exploration" => amount_of_programs_exploration,
        "max_depth_exploration" => max_depth_exploration,
        "learning_rate" => learning_rate,
        "amount_of_programs_explotation" => amount_of_programs_explotation,
        "max_size_explotation" => max_size_explotation,
        "model" => model,
        "embed_dim" => embed_dim,
        "hidden_dim" => hidden_dim,
        "results" => Dict(),
    )
    path = "ext/ThesisStef/results/$experiment_name/$filename.jld2"
    save(path, data)
    file_lock = ReentrantLock()

    problem_ids = collect(problem_ids)
    shuffle!(problem_ids)

    # @threads for problem_id in problem_ids
    for problem_id in problem_ids
        println("Problem $problem_id")

        iterations = []
        accuracy = 0

        train_triplets = generate_triplets_4(
            amount_of_programs=amount_of_programs_exploration,
            max_depth=max_depth_exploration,
            # max_size=max_depth_exploration,
            problem_id=problem_id,
            example_ids=example_ids)

        for _ in 1:repetitions
            m = get_distances_model(
                triplets=train_triplets, 
                embed_dim=embed_dim, 
                hidden_dim=hidden_dim,
                learning_rate=learning_rate)

            # m = get_direct_model(
            #     triplets=train_triplets, 
            #     embed_dim=embed_dim, 
            #     hidden_dim=hidden_dim,
            #     learning_rate=learning_rate)

            training_accuracy(m, train_triplets)

            i = test_best_first_iterator(
                model=m,
                use_levenshtein=false,
                max_iterations=amount_of_programs_explotation,
                max_size=max_size_explotation,
                problem_id=problem_id, 
                example_ids=example_ids)

            println("Took $i iterations")

            if i < amount_of_programs_explotation
                accuracy += 1 / repetitions
                push!(iterations, i)
            end

            return m
        end

        result = accuracy > 0 ? (accuracy, mean(iterations), std(iterations)) : (0, -1, -1)
        @show result
        
        lock(file_lock)
        try
            data = load(path)
            data["results"][problem_id] = result
            save(path, data)
        finally
            unlock(file_lock)
        end
    end
end

function load_data(experiment_name, file_names)
    results = Dict()

    for f in file_names
        results[f] = load("ext/ThesisStef/results/$experiment_name/$f.jld2")
    end

    return results
end

# -------------------
# 5. Execute
# -------------------

# embed_dim = parse(Int, ARGS[1])
# hidden_dim = parse(Int, ARGS[2])
# filename = "embed_dim=$embed_dim,hidden_dim=$hidden_dim"

# experiment_name = "playground"
# filename = "sorting_problems_on_difficulty"

# m = execute_experiment(;
#     experiment_name = experiment_name,
#     filename = filename,
#     repetitions = 1,
#     problem_ids = [15],
#     example_ids = 1:5,
#     amount_of_programs_exploration = 5000,
#     max_depth_exploration = 15,
#     learning_rate = 0.001,
#     amount_of_programs_explotation = 20,
#     max_size_explotation = 13,
#     model = "Embed -> GRU -> Embed",
#     embed_dim = 32,
#     hidden_dim = 32,
# )

model = Chain(
    Embedding(8 => 8),
    GRU(8 => 8)
)
character = 1

for n in 1:20
    stream = fill(character, n)
    value = model(stream)
    println(sum(value.^2))
end



#=

repetitions = 5,
example_ids = 1:5,
amount_of_programs_exploration = 200,
max_depth_exploration = 15,
learning_rate = 0.04,
amount_of_programs_explotation = 50,
max_size_explotation = 10,
model = "Embed -> GRU -> Dense",
embed_dim = 16,
hidden_dim = 16,
loss = triplet + L2 regularization


ID      Diff.       Acc         Iterations (ave, std)       Example input                                   Example output                    
5       Trivial     1.0         3.0      0.00               BA French                                       French
171     Easy        1.0         3.0      0.00               brown4 #8b2323                                  #8b2323
313     Easy        1.0         3.0      0.00               test.sh                                         sh
323     Easy        1.0         9.8      1.79               Boxing Day 8am-5pm                              8am-5pm
97      Medium      0.8         6.0      1.41               Here and There (2010)                           2010
230     Medium      0.8         38.0     9.09               -ge-fb-cs-gh-ag-nz                              gefbcsghagnz

317     Medium      0.0         NaN      NaN                University College, Oxford, OX1 4BH             University College, OX1 4BH"
167     Medium      0.0         NaN      NaN                $15.92($0.84 / 100 ml)                          15.92
235     Medium      0.0         NaN      NaN                yewjw.xbcmpvu.xabuh.                            yewjw.xbcmpvu
301     Medium      0.0         NaN      NaN                \"Reds\",82.20,97                               Reds
308     Medium      0.0         NaN      NaN                <country>Iceland</country>                      Iceland

=#