using HerbBenchmarks, HerbSearch, HerbConstraints, HerbCore, HerbGrammar
using Flux, Random, Statistics

include("string_grammar.jl")
include("best_first_string_iterator_2.jl")


# -------------------
# 1. Generate data
# -------------------

function generate_triplets(;
    problem_id,
    amount_of_programs,
    example_ids,
)
    function heuristic(iter, program, states)
        return length(program)
    end

    programs = BestFirstStringIterator(heuristic, problem_id, example_ids)
    triplets_apn = []

    @show programs.start_states
    @show programs.final_states
    println("\nGenerating triplets")


    for (i, (current, parent, grand_parent)) in enumerate(programs)
        # println()
        # @show i
        # @show current
        # @show parent
        # @show grand_parent

        if i >= amount_of_programs
            break
        end

        if i % 100 == 0
            println("Iterated through $i programs")
        end

        # @show [s.str for s in states]

        if !isnothing(parent.program)
            push!(triplets_apn, (grand_parent.states, parent.states, current.states))
            push!(triplets_apn, (current.states, parent.states, grand_parent.states))
        end
    end

    # for (a, p, n) in triplets_apn
    #     println()
    #     @show [(s.str, s.pointer) for s in a]
    #     @show [(s.str, s.pointer) for s in p]
    #     @show [(s.str, s.pointer) for s in n]
    # end

    s = length(triplets_apn)
    println("Generated $s triplets\n")

    return triplets_apn
end


# -------------------
# 2. Define model
# -------------------

charset = vcat(
    collect('a':'z'),
    collect('A':'Z'),
    collect('0':'9'),
    [' ', '|']
)
vocab = Dict(c => i for (i, c) in enumerate(charset))
vocab_size = 2 * length(vocab)


function encode_state(state)
    s = state.str

    idxs = [vocab[c] for c in collect(s)]
    
    if length(idxs) > 0
        if isnothing(state.pointer)
            idxs[length(idxs)] += 64
        else
            idxs[state.pointer] += 64
        end
    end

    if isempty(idxs)
        idxs = [1]
    end

    return Flux.onehotbatch(idxs, 1:vocab_size)
end

function distance_with_inf(e_from, e_to)
    if e_from[1] - e_to[1] > 0.00001
        return 10000
        # return sum((e_from - e_to).^2) + (e_from[1] - e_to[1]) * 9
    else
        return sum((e_from - e_to).^2)
    end
end

function get_distances_model(embed_dim, hidden_dim)
    model = Chain(
        Embedding(vocab_size, embed_dim),
        GRU(embed_dim => hidden_dim),
        x -> x[:, end],
    )

    function loss_triplet_alignment(model, anchors, positives, negatives)
        e_anchors   = model.(encode_state.(anchors))
        e_positives = model.(encode_state.(positives))
        e_negatives = model.(encode_state.(negatives))

        function triplet_loss(z1, z2, z3; margin=1)
            # d_positive = sum((z1 - z2).^2)
            # d_negative = sum((z1 - z3).^2)
            d_positive = distance_with_inf(z1, z2)
            d_negative = distance_with_inf(z1, z3)

            return max(0, d_positive - d_negative + margin)
        end
        
        function variance_loss(zs)
            m = mean(zs, dims=1)

            function single_loss(z)
                return sum((z - m[1]).^2)
            end

            return mean(single_loss.(zs))
        end

        function force_inf_direction(from, to)
            return max(0, from[1] - to[1] + 1)
        end

        # triplet = mean(triplet_loss.(e_anchors, e_positives, e_negatives))
        triplet = triplet_loss(mean(e_anchors), mean(e_positives), mean(e_negatives))

        align = variance_loss(e_anchors) + variance_loss(e_positives) + variance_loss(e_negatives)

        force =
            max(0, mean(e_positives)[1] - mean(e_anchors)[1] + 0.00002) + 
            # max(0, mean(e_negatives)[1] - mean(e_anchors)[1] + 1) + 
            max(0, mean(e_negatives)[1] - mean(e_positives)[1] + 0.00002)

        loss = triplet + align * 1 + force * 1

        return loss
    end

    println("Training model")
    opt_state = Flux.setup(RMSProp(), model)
    Flux.train!(loss_triplet_alignment, model, triplets, opt_state)
    println("Model trained")

    return model
end

function get_direct_model(embed_dim, hidden_dim)
    embedder = Chain(
        Embedding(vocab_size, embed_dim),
        GRU(embed_dim => hidden_dim),
        x -> x[:, end],
    )

    model = Chain(
        Parallel(vcat, embedder, embedder),
        Dense(2 * hidden_dim => 1),
        x -> x[1],
    )

    function loss_triplet_alignment(model, anchors, positives, negatives)
        a = encode_state.(anchors)
        p = encode_state.(positives)
        n = encode_state.(negatives)

        e_anchors = embedder.(encode_state.(anchors))
        e_positives = embedder.(encode_state.(positives))
        e_negatives = embedder.(encode_state.(negatives))

        values_positive = model.(zip(a, p))
        values_negative = model.(zip(a, n))

        function triplet_loss(v_positive, v_negative; margin=1)
            return max(0, v_positive - v_negative + margin)
        end
        
        function variance_loss(zs)
            m = mean(zs, dims=1)

            function single_loss(z)
                return sum((z - m[1]).^2)
            end

            return mean(single_loss.(zs))
        end

        # triplet = mean(triplet_loss.(values_positive, values_negative))
        triplet = triplet_loss(mean(values_positive), mean(values_negative))

        align = variance_loss(e_anchors) + variance_loss(e_positives) + variance_loss(e_negatives)
        loss = triplet + align

        return loss
    end

    println("Training model")
    opt_state = Flux.setup(RMSProp(), model)
    Flux.train!(loss_triplet_alignment, model, triplets, opt_state)
    println("Model trained")

    return model
end


# -------------------
# 3. Test
# -------------------

function distance(model, intermediate, target)
    e_target = model(encode_state(target))
    e_intermediate = model(encode_state(intermediate))
    return sum((e_target - e_intermediate).^2)
end

function average_distance(model, intermediates, targets)
    return mean([distance(model, i, t) for (i, t) in zip(intermediates, targets)])
end

function maximum_distance(model, intermediates, targets)
    return maximum([distance(model, i, t) for (i, t) in zip(intermediates, targets)])
end

function distance_between_average(model, intermediates, targets)
    e_target = mean(model.(encode_state.(targets)))
    e_intermediate = mean(model.(encode_state.(intermediates)))
    # return sum((e_target - e_intermediate).^2)
    return distance_with_inf(e_intermediate, e_target)
end

function training_accuracy_distance_model(model, triplets)
    println("\nTesting model")
    score = 0
    total = 0

    for (as, ps, ns) in triplets
        total += 1

        # if average_distance(model, as, ps) < average_distance(model, as, ns)
        if distance_between_average(model, as, ps) < distance_between_average(model, as, ns)
            score += 1
        end
    end

    acc = score / total
    accr = round(acc, digits=2)
    println("Accuracy: $accr")

    return acc
end

function training_accuracy_direct_model(model, triplets)
    println("\nTesting model")
    score = 0
    total = 0

    for (as, ps, ns) in triplets
        total += 1

        a = encode_state.(as)
        p = encode_state.(ps)
        n = encode_state.(ns)

        value_positive = mean(model.(zip(a, p)))
        value_negative = mean(model.(zip(a, n)))
        
        if value_positive < value_negative
            score += 1
        end
    end

    acc = score / total
    accr = round(acc, digits=2)
    println("Accuracy: $accr")

    return acc
end

function test_best_first_iterator(; max_iterations, problem_id, example_ids)
    function heuristic(iter, program, states)
        return distance_between_average(model, states, iter.final_states)
        # return maximum_distance(model, states, iter.final_states)
    end

    programs = BestFirstStringIterator(heuristic, problem_id, example_ids)


    for (i, (current, parent, grand_parent)) in enumerate(programs)
        println()
        @show current.program
        @show [s.str for s in current.states]

        if current.states == programs.final_states
            println("Found $program")
            break
        end

        if i == max_iterations
            break
        end

        i += 1
    end
end

function rank_intermediates(model, intermediates, target)
    d(intermediate) = distance_between_average(model, [intermediate], [target])
    sort!(intermediates, by = d)

    return intermediates
end

function test_ordering()
    println("")
    intermediates = ["2005 Ford Puma", "005 Ford Puma", "05 Ford Puma", "5 Ford Puma", " Ford Puma", "Ford Puma", "ord Puma", "rd Puma", "d Puma", " Puma"]
    target = HerbBenchmarks.String_transformations_2020.StringState("Puma", 4)
    intermediates = [HerbBenchmarks.String_transformations_2020.StringState(str, 1) for str in intermediates]
    rank_intermediates(model, intermediates, target)

    for intermediate in intermediates
        v = distance_between_average(model, [intermediate], [target])
        println(round(v, digits = 4), "\t", intermediate)
    end

    println("")
    intermediates = ["2005 ford Puma", "2005 FOrd Puma", "2005 FORD PUMA", "PUMA", "2005", "Ford", "uma", "ma", "a", "Ford 2005 Puma", "Puma Ford 2005", ""]
    target = HerbBenchmarks.String_transformations_2020.StringState("Puma", 4)
    intermediates = [HerbBenchmarks.String_transformations_2020.StringState(str, 1) for str in intermediates]
    rank_intermediates(model, intermediates, target)

    for intermediate in intermediates
        v = distance_between_average(model, [intermediate], [target])
        println(round(v, digits = 4), "\t", intermediate)
    end
end

# -------------------
# 4. Execute
# -------------------

# triplets = generate_triplets(
#     amount_of_programs=1000,
#     problem_id=102,  
#     example_ids=1:5)

# model = get_distances_model(4, 4)
# training_accuracy_distance_model(model, triplets)

# test_best_first_iterator(
#     max_iterations=100,
#     problem_id=102, 
#     example_ids=1:5)

# test_ordering()