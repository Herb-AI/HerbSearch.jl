using HerbBenchmarks, HerbSearch, HerbConstraints, HerbCore, HerbGrammar
using Flux, Random, Statistics

include("string_grammar.jl")
include("best_first_string_iterator.jl")

# -------------------
# 1. Generate data
# -------------------

function get_all_subprograms(program)
    result = []

    for child in program.children
        if typeof(child) != HerbConstraints.StateHole
            push!(result, child)
        end

        [push!(result, child_subprograms) for child_subprograms in get_all_subprograms(child)]
    end

    return result
end


function state_to_repr(state)
    return state.str

    if state.pointer <= 0
        return (state.str, -1)
    end

    if length(state.str) == 1
        return (state.str, 1)
    end
    
    f = (state.pointer - 1) / (length(state.str) - 1)
    return (state.str, f)
end


function generate_data(max_programs; examples=1:5, individual_pairs=false, include_no_transformation=false)
    benchmark       = HerbBenchmarks.String_transformations_2020
    problem_grammar = get_all_problem_grammar_pairs(benchmark)[102]
    problem         = problem_grammar.problem
    spec            = problem.spec[examples]
    inputs          = [state_to_repr(example.in[:_arg_1]) for example in spec]
    iterator        = HerbSearch.BFSIterator(grammar, :Program, max_depth=10)

    # println("Inputs")
    # println(inputs)

    # println("\nDesired outputs")
    # println([example.out.str for example in spec])

    if include_no_transformation
        if individual_pairs
            data = [((input, input), 0) for input in inputs]
        else
            data = [((inputs, inputs), 0)]
        end
    else
        data = []
    end
    outputs_to_size = Dict(inputs => 0)
    program_to_outputs = Dict()

    extra = 0

    for (i, program) in enumerate(iterator)
        # println("\n\n")
        # println(program)

        if i >= max_programs
            break
        end

        outputs = nothing

        try
            outputs = [state_to_repr(benchmark.interpret(program, benchmark.get_relevant_tags(grammar), example.in[:_arg_1])) for example in spec]
        catch e
            if typeof(e) == BoundsError
                # println("out of bounds")
                continue
            else
                rethrow(e)
            end
        end

        size = length(program)

        if haskey(outputs_to_size, outputs)
            # println("not useful: $(outputs[1])")
            continue
        end

        # println("    useful: $(outputs[1])")

        if individual_pairs
            [push!(data, ((input, output), size)) for (input, output) in zip(inputs, outputs)]
        else
            push!(data, ((inputs, outputs), size))
        end

        outputs_to_size[outputs] = size
        program_to_outputs["$(program)"] = outputs


        for subprogram in get_all_subprograms(program)

            if haskey(program_to_outputs, "$subprogram")
                i_outputs = program_to_outputs["$subprogram"]
                i_size = outputs_to_size[i_outputs]

                if individual_pairs
                    [push!(data, ((i_output, output), size - i_size)) for (i_output, output) in zip(i_outputs, outputs)]
                else
                    push!(data, ((i_outputs, outputs), size - i_size))
                end

                # println("\n $i")
                # println(program)
                # println(subprogram)

                extra += 1
            end
        end
    end

    # for (program, outputs) in program_to_outputs
    #     println("")
    #     println(program)
    #     println(outputs[1])
    # end

    # println(extra)

    return data
end


function create_triplets(n, data; include_equal=true)
    triplets = []

    while length(triplets) < n
        x1 = rand(data)
        x2 = rand(data)

        if x1[1][1] != x2[1][1]
            continue
        end

        if !include_equal && x1[2] == x2[2]
            continue
        end

        equal_distance = x1[2] == x2[2]

        if x1[2] < x2[2]
            push!(triplets, (x1[1][1], x1[1][2], x2[1][2], equal_distance))
        else
            push!(triplets, (x1[1][1], x2[1][2], x1[1][2], equal_distance))
        end
    end

    return triplets
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

function encode_string(s)
    idxs = [vocab[c] for c in collect(s)]

    if isempty(idxs)
        # If string is empty, feed a single “padding index”
        idxs = [1]
    end

    return Flux.onehotbatch(idxs, 1:length(vocab))
end


function get_model(embed_dim, hidden_dim)
    return Chain(
        Embedding(length(vocab), embed_dim),
        GRU(embed_dim => hidden_dim),
        x -> x[:, end],
    )
end


# -------------------
# 3. Define optimization
# -------------------

function loss_triplet_alignment(model, anchors, positives, negatives, equal_distance)
    e_anchors   = model.(encode_string.(anchors))
    e_positives = model.(encode_string.(positives))
    e_negatives = model.(encode_string.(negatives))

    function triplet_loss(z1, z2, z3; margin=1)
        d_positive = sum((z1 - z2).^2)
        d_negative = sum((z1 - z3).^2)

        return max(0, d_positive - d_negative + margin)
    end
    
    function variance_loss(zs)
        m = mean(zs, dims=1)

        function single_loss(z)
            return sum((z - m[1]).^2)
        end

        return mean(single_loss.(zs))
    end

    triplet = mean(triplet_loss.(e_anchors, e_positives, e_negatives))

    align = variance_loss(e_anchors) + variance_loss(e_positives) + variance_loss(e_negatives)
    loss = triplet + align

    return loss
end

function loss_triplet(model, anchors, positives, negatives, equal_distance)
    e_anchors   = model.(encode_string.(anchors))
    e_positives = model.(encode_string.(positives))
    e_negatives = model.(encode_string.(negatives))

    function triplet_loss(z1, z2, z3; margin=1)
        d_positive = sum((z1 - z2).^2)
        d_negative = sum((z1 - z3).^2)

        return max(0, d_positive - d_negative + margin)
    end

    loss = mean(triplet_loss.(e_anchors, e_positives, e_negatives))

    return loss
end

function train_model(model, data)
    opt_state = Flux.setup(RMSProp(), model)
    Flux.train!(loss_triplet_alignment, model, data, opt_state)
end


# -------------------
# 4. Test
# -------------------

function distance(model, intermediate, target)
    e_target = model.(encode_string.(target))
    e_intermediate = model.(encode_string.(intermediate))
    return sum((e_target - e_intermediate).^2)
end

function average_distance(model, intermediates, targets)
    return mean([distance(model, i, t) for (i, t) in zip(intermediates, targets)])
end

function distance_between_averages(model, intermediates, targets)
    e_target = mean(model.(encode_string.(targets)))
    e_intermediate = mean(model.(encode_string.(intermediates)))
    return sum((e_target - e_intermediate).^2)
end

function rank_intermediates(model, intermediates, target)
    d(intermediate) = distance(model, intermediate, target)
    sort!(intermediates, by = d)

    return intermediates
end

function rank_list_of_intermediates(model, intermediatess, targets)
    d(intermediates) = average_distance(model, intermediates, targets)
    sort!(intermediatess, by = d)

    return intermediatess 
end

function training_accuracy(model, triplets)
    score = 0
    total = 0

    for (as, ps, ns) in triplets
        for (a, p, n) in zip(as, ps, ns)
            total += 1

            if distance(model, p, a) < distance(model, n, a)
                score += 1
            end
        end
    end

    return score / total
end


# -------------------
# 5. Execute
# -------------------

println("Generating data")
data = generate_data(3000, examples=1:5, include_no_transformation=false)
println("Data generated")

println("\nGenerating triplets")
triplets = create_triplets(5000, data, include_equal=false)
println("Triplets generated")

println("\nTraning model")
model = get_model(16, 16)
train_model(model, triplets)
println("Model trained")

println("\nTesting model")
# data = generate_data(1000, examples=1:5)
# triplets = create_triplets(5000, data, include_equal=false)
training_acc = round(training_accuracy(model, triplets), digits=2)
println("Accuracy: $training_acc")


# -------------------
# 6. Experiment
# -------------------

function test_best_first_iterator()
    benchmark       = HerbBenchmarks.String_transformations_2020
    problem_grammar = get_all_problem_grammar_pairs(benchmark)[102]
    problem         = problem_grammar.problem
    spec            = problem.spec[1:5]
    targets         = [example.out.str for example in spec]

    seen_intermediates = Dict()

    function heuristic(program::AbstractRuleNode)
        try
            intermediates = [benchmark.interpret(program, benchmark.get_relevant_tags(grammar), example.in[:_arg_1]) for example in spec]

            if haskey(seen_intermediates, intermediates)
                return Inf
            end
            
            d = average_distance(model, state_to_repr.(intermediates), targets)
            seen_intermediates[intermediates] = d

            return d
        catch e
            if typeof(e) == BoundsError
                return Inf
            end

            rethrow(e)
        end
    end

    iter = BestFirstStringIterator(heuristic)

    for (i, program) in enumerate(iter)
        # println(program)
        # println(heuristic(program))
        # println()

        intermediates = [benchmark.interpret(program, benchmark.get_relevant_tags(grammar), example.in[:_arg_1]) for example in spec]
        h = seen_intermediates[intermediates]

        if h == 0
            println("Found $program")
            break
        end

        if i % 1 == 0
            println("$i \t $h \t $program")
            println(state_to_repr.(intermediates), "\n")
        end

        if i == 50
            break
        end

        i += 1
    end
end


function test_ordering()
    println("")
    intermediates = ["2005 Ford Puma", "005 Ford Puma", "05 Ford Puma", "5 Ford Puma", " Ford Puma", "Ford Puma", "ord Puma", "rd Puma", "d Puma", " Puma"]
    target = "Puma"

    rank_intermediates(model, intermediates, target)

    for intermediate in intermediates
        dist = distance(model, intermediate, target)
        println(round(dist, digits = 4), "\t", intermediate)
    end

    println("")
    intermediates = ["2005 ford Puma", "2005 FOrd Puma", "2005 FORD PUMA", "PUMA", "2005", "Ford", "uma", "ma", "a", "Ford 2005 Puma", "Puma Ford 2005", ""]
    target = "Puma"
    rank_intermediates(model, intermediates, target)

    for intermediate in intermediates
        dist = distance(model, intermediate, target)
        println(round(dist, digits = 4), "\t", intermediate)
    end
end


test_ordering()

test_best_first_iterator()
