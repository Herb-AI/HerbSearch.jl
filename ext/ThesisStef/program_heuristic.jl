using HerbBenchmarks, HerbSearch, HerbConstraints, HerbCore, HerbGrammar
using Flux, Random, Statistics, JLD2, Dates, Base.Threads

include("string_grammar.jl")
include("best_first_string_iterator.jl")
include("known_heuristics.jl")

# -------------------
# 1. Data
# -------------------

function generate_triplets(;
    amount_of_programs,
    max_size,
    problem_id,
    example_ids,
    include_no_transformation=false,
)
    function heuristic(_, program, _)
        l = length(program)
        return l < max_size ? l : Inf
    end

    iter = BestFirstStringIterator(heuristic, max_size, problem_id, example_ids)

    # @show [s.str for s in iter.start_states]
    # @show [s.str for s in iter.final_states]
    # println("\nGenerating triplets")

    triplets_apn = []
    input_to_outputs_and_costs = include_no_transformation ?
        Dict(iter.start_states => [(iter.start_states, 0)]) :
        Dict(iter.start_states => [])

    function add_path!(input_entry, output_states, distance)
        if !isnothing(input_entry)
            # println("\nAdding: from\t $(input_entry.states[1])")
            # println("to\t\t $(output_states[1])")
            # println("cost\t\t $distance \n")
            push!(input_to_outputs_and_costs[input_entry.states], (output_states, distance))
            add_path!(input_entry.parent, output_states, distance + 1)
        end
    end


    for (i, entry) in enumerate(iter)
        # println()
        # @show i
        # @show entry.program
        # @show entry.states[1]
        # @show entry.parent.states[1]

        input_to_outputs_and_costs[entry.states] = include_no_transformation ?
            [(entry.states, 0)] : []
        
        add_path!(entry.parent, entry.states, 1)

        if i >= amount_of_programs
            break
        end
    end

    # println("\n\n\n")

    for (inputs, outputs_and_costs) in input_to_outputs_and_costs
        for (outputs_1, cost_1) in outputs_and_costs
            for (outputs_2, cost_2) in outputs_and_costs
                if cost_1 < cost_2
                    push!(triplets_apn, (inputs, outputs_1, outputs_2))
                end
            end
        end
    end

    # for (a, p, n) in triplets_apn
    #     @show a[1]
    #     @show p[1]
    #     @show n[1]
    #     println()
    # end

    s = length(triplets_apn)
    n = length([a for (a, n, p) in triplets_apn if a != iter.start_states])
    # println("Generated $s triplets of which $n have different input state than the task\n")

    return triplets_apn
end

function generate_triplets_2(;
    amount_of_programs,
    max_size,
    problem_id,
    example_ids,
)
    function heuristic(_, program, _)
        l = length(program)
        return l < max_size ? l : Inf
    end

    iter = BestFirstStringIterator(heuristic, max_size, false, problem_id, example_ids)

    @show [s.str for s in iter.start_states]
    @show [s.str for s in iter.final_states]
    println("\nGenerating triplets")

    shortest_paths = Dict((iter.start_states, iter.start_states) => 0)


    for (i, entry) in enumerate(iter)
        # println()
        # @show i
        # @show entry.program
        # @show entry.states[1]
        # @show entry.parent.states[1]

        # if not exists
        if !haskey(shortest_paths, (entry.states, entry.states))
            shortest_paths[(entry.states, entry.states)] = 0
        end

        for ((states_in, states_out), size) in shortest_paths
            if states_out == entry.parent.states && !haskey(shortest_paths, (states_in, entry.states))
                shortest_paths[(states_in, entry.states)] = size + 1
            end
        end

        if i == amount_of_programs
            break
        end
    end

    triplets_anp = []
    equal_inputs = 0
    equal_outputs = 0

    for ((state_in_1, state_out_1), size_1) in shortest_paths
        for ((state_in_2, state_out_2), size_2) in shortest_paths
            if size_1 < size_2
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

    @show equal_inputs
    @show equal_outputs
    @show length(triplets_anp)

    return triplets_anp
end


# -------------------
# 2. Encoding
# -------------------

charset = vcat(
    collect('a':'z'),
    collect('A':'Z'),
    collect('0':'9'),
    [' ', '.', ',', '-', '(', ')', '@', ':', ';', '_', '/', '\\', '<', '>', '#', '\'']
)
vocab = Dict(c => i for (i, c) in enumerate(charset))
vocab_size = length(vocab) * 2 + 1

function encode_state(state)
    s = state.str

    idxs = [vocab[c] for c in collect(s)]
    idxs = [2*vocab[c] for c in collect(s)]
    
    if length(idxs) > 0
        if isnothing(state.pointer)
            idxs[length(idxs)] += 1
        else
            idxs[state.pointer] += 1
        end
    end

    if isempty(idxs)
        idxs = [1]
    end

    return Flux.onehotbatch(idxs, 1:vocab_size)
end


# -------------------
# 3. Model
# -------------------

function get_distances_model(;triplets, embed_dim, hidden_dim, learning_rate)
    model = Chain(
        Embedding(vocab_size, embed_dim),
        GRU(embed_dim => hidden_dim),
        x -> x[:, end],
    )

    function loss_triplet_alignment(model, anchors, positives, negatives)
        e_anchors   = model.(encode_state.(anchors))
        e_positives = model.(encode_state.(positives))
        e_negatives = model.(encode_state.(negatives))

        function triplet_loss(z1, z2, z3; margin=.1)
            d_positive = sum((z1 - z2).^2)
            d_negative = sum((z1 - z3).^2)

            return max(0, d_positive - d_negative + margin)
        end
        
        # function variance_loss(zs)
        #     m = mean(zs, dims=1)

        #     function single_loss(z)
        #         return sum((z - m[1]).^2)
        #     end

        #     return mean(single_loss.(zs))
        # end

        triplet = mean(triplet_loss.(e_anchors, e_positives, e_negatives))
        # align = variance_loss(e_anchors) + variance_loss(e_positives) + variance_loss(e_negatives)

        return triplet
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
    return mean([sum((i - o).^2) for (i, o) in zip(e_ins, e_outs)])
end

function levenshtein_heuristic(input_states, output_states)
    total = 0

    for (i, o) in zip(input_states, output_states)
        total += ls!(i.str, o.str, 1, 1, 1)
    end

    return total
end

function training_accuracy(model, triplets)
    println("\nTesting model")
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
    # heuristic(iter, program, states) = use_levenshtein ? 
    #     levenshtein_heuristic(states, iter.final_states) :
    #     model_heuristic(model, states, iter.final_states)

    heuristic(iter, program, states) = length(program) 

    function state_to_str(state)
        return "$(state.str) | $(state.pointer)"
    end

    iter = BestFirstStringIterator(heuristic, max_size, true, problem_id, example_ids)


    for (i, entry) in enumerate(iter)
        # println()
        @show i
        # @show entry.program
        # @show state_to_str.(entry.states)

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
    max_size_exploration = 7,
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
        "max_size_exploration" => max_size_exploration,
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

    @threads for problem_id in problem_ids
        println("Problem $problem_id")

        iterations = []
        accuracy = 0

        train_triplets = generate_triplets_2(
            amount_of_programs=amount_of_programs_exploration,
            max_size=max_size_exploration,
            problem_id=problem_id,
            example_ids=example_ids)

        for _ in 1:repetitions
            m = get_distances_model(
                triplets=train_triplets, 
                embed_dim=embed_dim, 
                hidden_dim=hidden_dim,
                learning_rate=learning_rate)

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
        end

        result = accuracy > 0 ? (accuracy, mean(iterations), std(iterations)) : (0, -1, -1)
        
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

function obtain_accuracies(data)
    accuracies = Dict()

    for (name, results) in data
        as = [id => acc for (id, (acc, ave, std)) in results["results"]]
        ave = mean([acc for (id, (acc, ave, std)) in results["results"]])
        accuracies[name] = (ave, as)
    end

    return accuracies
end

function obtain_iterations(data)
    accuracies = Dict()

    for (name, results) in data
        is = [id => (ave, std) for (id, (acc, ave, std)) in results["results"]]
        ave = mean([ave for (id, (acc, ave, std)) in results["results"] if ave != -1])
        accuracies[name] = (ave, is)
    end

    return accuracies
end

function display_results(data)
    println("\n")

    for (filename, (average_accuracy, accuracy_per_problem)) in obtain_accuracies(data)
        @show filename
        @show average_accuracy
        @show accuracy_per_problem
        println()
    end

    for (filename, (average_iterations, iterations_per_problem)) in obtain_iterations(data)
        @show filename
        @show average_iterations
        @show iterations_per_problem
        println()
    end

    for ((filename, (average_accuracy, _)), (filename, (average_iterations, _))) in zip(obtain_accuracies(data), obtain_iterations(data))
        println(filename, " -> average accuracy: ", average_accuracy, " & average iterations: ", average_iterations)
    end
end

# -------------------
# 5. Execute
# -------------------

# embed_dim = parse(Int, ARGS[1])
# hidden_dim = parse(Int, ARGS[2])
# filename = "embed_dim=$embed_dim,hidden_dim=$hidden_dim"

# experiment_name = "playground"
# filename = "testing_new_data_generation"

# execute_experiment(;
#     experiment_name = experiment_name,
#     filename = filename,
#     repetitions = 5,
#     problem_ids = 102,
#     example_ids = 1:5,
#     amount_of_programs_exploration = 300,
#     max_size_exploration = 10,
#     learning_rate = 0.04,
#     amount_of_programs_explotation = 150,
#     max_size_explotation = 10,
#     model = "Embed -> GRU",
#     embed_dim = 4,
#     hidden_dim = 4,
# )

# data = load_data("model_size", [filename])
# display_results(data)

i = test_best_first_iterator(
                model=nothing,
                use_levenshtein=true,
                max_iterations=150,
                max_size=10,
                problem_id=102, 
                example_ids=1:5)