using Flux
using Statistics: mean
using Random
using HerbBenchmarks, HerbSearch
using LinearAlgebra
device = gpu_device()


# ------------------------
# 1. Hyperparameters
# ------------------------
charset = vcat(
    collect('a':'z'),
    collect('A':'Z'),
    collect('0':'9'),
    [' ', '|']
)
vocab = Dict(c => i for (i, c) in enumerate(charset))
inv_vocab = Dict(i => c for (c, i) in vocab)
vocab_size = length(vocab)


# Encode string → one-hot sequence
function encode_string(s::String)
    idxs = [vocab[c] for c in collect(s)]

    if isempty(idxs)
        # If string is empty, feed a single “padding index”
        idxs = [1]
    end

    return Flux.onehotbatch(idxs, 1:vocab_size)
end

# ------------------------
# 2. Encoder model
# ------------------------
function define_model()
    embed_dim = 10
    hidden_dim_1 = 16
    hidden_dim_2 = 16
    # output_dim = 128

    encoder = Chain(
        Embedding(vocab_size, embed_dim),
        GRU(embed_dim => hidden_dim_1),
        x -> x[:, end],
        # x -> mean(x, dims=2),
        # Dense(hidden_dim, output_dim),
    )

    combiner = Chain(
        # Flux.Bilinear((hidden_dim_1, hidden_dim_1) => hidden_dim_2),
        xy -> sum(xy[1] .- xy[2])^2,
        # Dense(hidden_dim_2 => 1, tanh),
        # Flux.Scale(1)
    )

    model = Parallel(combiner, encoder)

    return model
end

function compute_distance(model, e_source, e_target)
    # e1 = model(e_source)
    # e2 = model(e_target)
    # dif = abs(sum(e1 - e2))
    # return 10 * dif^2

    v = model((e_source, e_target))[1]
    return exp(v) - 1
end


# function train_model(iterations, model, size_to_outputs, outputs_to_size)
#     opt_state = Flux.setup(Flux.Adam(), model)

#     function train_step!(source, target, distance)
#         e_source = encode_string(source)
#         e_target = encode_string(target)

#         lo, gs = Flux.withgradient(m -> begin
#             dist = compute_distance(model, e_source, e_target)
#             # dist = model((e_source, e_target))[1]
#             return (distance - dist)^2
#         end, model)

#         Flux.update!(opt_state, model, gs[1])
#     end

#     sizes = keys(size_to_outputs)

#     for i in 1:iterations
#         if i % 250 == 0
#             println(i)
#         end

#         size = rand(sizes)
#         outputs = rand(size_to_outputs[size])
#         [train_step!(input, output, size) for (input, output) in zip(inputs, outputs)]
#     end
# end

function train_model(iterations, model, data)

    loss(m, x, y) = (m((x, y)) - y)^2

    opt_state = Flux.setup(Momentum(0.1), model)
    Flux.train!(loss, model, data, opt_state)
end


# ------------------------
# 6. Generate data from BFS
# ------------------------
function state_to_str(state)
    p = max(0, state.pointer)
    return "$(state.str)"
end


function generate_data(depth)
    benchmark       = HerbBenchmarks.String_transformations_2020
    problem_grammar = get_all_problem_grammar_pairs(benchmark)[102]
    problem         = problem_grammar.problem
    spec            = problem.spec[1:5]
    inputs          = [state_to_str(example.in[:_arg_1]) for example in spec]
    grammar         = problem_grammar.grammar
    iterator        = HerbSearch.BFSIterator(grammar, :Sequence, max_depth=depth)



    println("Inputs")
    println(inputs)

    println("\nDesired outputs")
    println([example.out.str for example in spec])

    size_to_outputs = Dict(0 => Set([inputs]))
    outputs_to_size = Dict(inputs => 0)
    data = [(input, 0) for input in inputs]

    for (i, program) in enumerate(iterator)
        outputs = nothing

        try
            # outputs = [benchmark.interpret(program, grammar, example).str for example in spec]
            outputs = [state_to_str(benchmark.interpret(program, benchmark.get_relevant_tags(grammar), example.in[:_arg_1])) for example in spec]
        catch BoundsError
            continue
        end

        size = length(program)

        if !haskey(outputs_to_size, outputs)
            outputs_to_size[outputs] = size

            if !haskey(size_to_outputs, size)
                size_to_outputs[size] = Set()
            end

            push!(size_to_outputs[size], deepcopy(outputs))
            [push!(data, (deepcopy(output), size)) for output in outputs]
        elseif outputs_to_size[outputs] > size
            println("aaaa")
        end
    end

    println("")
    println(size_to_outputs)
    println("")

    return inputs, size_to_outputs, outputs_to_size, data
end

# for (key, value) in size_to_outputs
#     println("\n")
#     println(key)

#     for s in value
#         println(s)
#     end
# end



# function test_source_targets(model, source, targets)
#     for target in targets
#         x1 = encode_string(source)
#         x2 = encode_string(target)
#         v = round(compute_distance(model, x1, x2), digits=2)
#         println("$v \t: $target")
#     end
# end

function test_random(n, inputs, size_to_outputs)
    sizes = keys(size_to_outputs)

    for _ in 1:n
        size = rand(sizes)
        outputs = rand(size_to_outputs[size])
        index = rand(1:length(inputs))
        output = outputs[index]
        input = inputs[index]

        x1 = encode_string(input)
        x2 = encode_string(output)
        # v = round(model((x1, x2))[1], digits=2)
        v = round(compute_distance(model, x1, x2), digits=2)
        
        println("$v \t $size \t: $output")
    end
end


model = define_model()
inputs, size_to_outputs, outputs_to_size, data = generate_data(6)
train_model(5000, model, data)
test_random(100, inputs, size_to_outputs)
