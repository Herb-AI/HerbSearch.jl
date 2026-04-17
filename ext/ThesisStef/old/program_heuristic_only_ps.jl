using HerbBenchmarks, HerbSearch, HerbConstraints, HerbCore, HerbGrammar
using Flux, Random, Statistics, JLD2, Dates, Base.Threads

include("string_grammar.jl")
include("best_first_string_iterator.jl")
include("known_heuristics.jl")
include("property_signatures.jl")

# -------------------
# 1. Data
# -------------------

function generate_triplets(;
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

        if i == amount_of_programs
            break
        end
    end

    states = collect(Set(values(program_to_state)))
    triplets_anp = []
    equal_inputs = 0
    equal_outputs = 0

    for ((states_1, states_2), size) in shortest_paths
        if !haskey(shortest_paths, (states_2, states_1)) #&& size < 4
            shortest_paths[(states_2, states_1)] = 1000
        end
    end

    for ((state_in_1, state_out_1), size_1) in shortest_paths
        for ((state_in_2, state_out_2), size_2) in shortest_paths
            # if size_1 < size_2
            if size_1 == 1 && size_2 > 1

                # Case 1: equal inputs
                if state_in_1 == state_in_2
                    push!(triplets_anp, (state_in_1, state_out_1, state_out_2))
                    equal_inputs += 1
                end

                # Case 2: equal outputs
                if state_out_1 == state_out_2
                    push!(triplets_anp, (state_out_1, state_in_1, state_in_2))
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
# 2. Model
# -------------------

function custom_distance(e1, e2)
    # if e1[1] - e2[1] > 0.01
    #     return sum((e1 - e2).^2) + (e1[1] - e2[1] - 0.01) * 100
    # else
    #     return sum((e1 - e2).^2)
    # end

    return sum((e1 - e2).^2)
end

function model_heuristic(model, input_states, output_states)
    if input_states == output_states
        return -Inf
    end

    # distance(i, o) = sum((i - o).^2)

    # signs_i = individual_properties.(input_states)
    # signs_o = individual_properties.(output_states)
    signs = property_signature.(input_states, output_states)

    # embeddings_i = model.(signs_i)
    # embeddings_o = model.(signs_o)

    # distances_io = custom_distance.(embeddings_i, embeddings_o)
    values_io = model.(signs)

    # return mean(distances_io)
    return mean(values_io)
end

function training_accuracy(model, triplets)
    # println("\nTesting model")
    score = 0
    total = 0

    for (as, ps, ns) in triplets
        total += 1

        if model_heuristic(model, as, ps) < model_heuristic(model, as, ns)
            score += 1
        end
    end

    acc = score / total
    accr = round(acc, digits=2)
    println("Training accuracy: $accr")

    return acc
end

function get_model(;triplets, embed_dim, hidden_dim, learning_rate)
    ps = property_signature_size

    model = Chain(
        Dense(ps => 2 * ps, tanh),
        Dense(2 * ps => ps, tanh),
        Dense(ps => ps, tanh),
        Dense(ps => 1, tanh),
        x -> x[1],
    )

    function loss(model, anchors, positives, negatives)
        distance(i, o) = sum((i - o).^2)
        triplet_loss(d_ap, d_an) = max(0, d_ap - d_an + .01)
        allignment_loss(es) = sum([distance(mean(es), e) for e in es])

        # signs_a = individual_properties.(anchors)
        # signs_p = individual_properties.(positives)
        # signs_n = individual_properties.(negatives)
        signs_ap = property_signature.(anchors, positives)
        signs_an = property_signature.(anchors, negatives)

        # embeddings_a = model.(signs_a)
        # embeddings_p = model.(signs_p)
        # embeddings_n = model.(signs_n)

        # distances_ap = custom_distance.(embeddings_a, embeddings_p)
        # distances_pn = custom_distance.(embeddings_a, embeddings_n)

        values_ap = model.(signs_ap)
        values_an = model.(signs_an)

        # triplet_losses = triplet_loss.(distances_ap, distances_pn)
        triplet_losses = triplet_loss.(values_ap, values_an)

        # regularization_loss = sum(x -> sum(abs2, x)/2, Flux.trainables(model))
        # allignment_losses = [allignment_loss(embeddings_a), allignment_loss(embeddings_p), allignment_loss(embeddings_n)]
        

        total_loss = mean(triplet_losses) #+ regularization_loss #+ mean(allignment_losses)

        return total_loss
    end

    # println("Training model")
    shuffle!(triplets)
    opt_state = Flux.setup(RAdam(), model)
    for _ in 1:3
        Flux.train!(loss, model, triplets, opt_state)
        training_accuracy(model, triplets)
    end
    # println("Model trained")

    return model
end


# -------------------
# 4. Test
# -------------------

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

        train_triplets = generate_triplets(
            amount_of_programs=amount_of_programs_exploration,
            max_depth=max_depth_exploration,
            # max_size=max_depth_exploration,
            problem_id=problem_id,
            example_ids=example_ids)

        for _ in 1:repetitions
            m = get_model(
                triplets=train_triplets, 
                embed_dim=embed_dim, 
                hidden_dim=hidden_dim,
                learning_rate=learning_rate)

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


# -------------------
# 5. Execute
# -------------------

# embed_dim = parse(Int, ARGS[1])
# hidden_dim = parse(Int, ARGS[2])
# filename = "embed_dim=$embed_dim,hidden_dim=$hidden_dim"

experiment_name = "playground"
filename = "sorting_problems_on_difficulty"

m = execute_experiment(;
    experiment_name = experiment_name,
    filename = filename,
    repetitions = 5,
    problem_ids = [5],
    example_ids = 1:5,
    amount_of_programs_exploration = 5000,
    max_depth_exploration = 15,
    learning_rate = 0.004,
    amount_of_programs_explotation = 10,
    max_size_explotation = 10,
    model = "Embed -> GRU -> Embed",
    embed_dim = 16,
    hidden_dim = 16,
)


# data = load_data("model_size", [filename])
# display_results(data)


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


301:
drop
while isLetter moveRight
while notAtEnd drop
drop



317     Medium      0.0         NaN      NaN                University College, Oxford, OX1 4BH             University College, OX1 4BH"
167     Medium      0.0         NaN      NaN                $15.92($0.84 / 100 ml)                          15.92
235     Medium      0.0         NaN      NaN                yewjw.xbcmpvu.xabuh.                            yewjw.xbcmpvu
301     Medium      0.0         NaN      NaN                \"Reds\",82.20,97                               Reds
308     Medium      0.0         NaN      NaN                <country>Iceland</country>                      Iceland

=#