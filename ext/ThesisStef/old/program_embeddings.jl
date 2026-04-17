using Flux
using Statistics: mean
using Random
using HerbBenchmarks, HerbSearch
using LinearAlgebra
device = gpu_device()


# ------------------------
# 1. Hyperparameters
# ------------------------
alphabet = vcat(
    collect('a':'z'),
    collect('A':'Z'),
    collect('0':'9'),
    [' ', '!', ',', '.', '?', '@']
)
char_to_idx = Dict(c => i for (i, c) in enumerate(alphabet))
vocab_size = length(alphabet)

hidden_dim = 32
seq_len = 50
lr = 1e-3

function string_to_tensor(s::String, maxlen::Int)
    chars = collect(s[1:min(end, maxlen)])
    padded = vcat(chars, fill(' ', maxlen - length(chars)))
    idxs = [char_to_idx[c] for c in padded]
    return Float32.(Flux.onehotbatch(idxs, 1:vocab_size))  # dense
end


# ------------------------
# 2. Encoder model
# ------------------------
model = Flux.LSTM(vocab_size => hidden_dim)
opt_state = Flux.setup(Flux.Adam(), model)

function train_step!(anchor, positive, negative)
    lo, gs = Flux.withgradient(m -> begin
        l = triplet_loss(anchor, positive, negative)
        return l
    end, model) #

    Flux.update!(opt_state, model, gs[1])
end


# ------------------------
# 3. Program Embedding (aggregate outputs)
# ------------------------
function program_embedding(outputs)
    embeddings = [model(string_to_tensor(output, seq_len)) for output in outputs]
    return mean(embeddings)
end


# ------------------------
# 4. Triplet Loss
# ------------------------
function triplet_loss(anchor, positive, negative; margin=1.0)
    d_pos = sum((anchor .- positive).^2)
    d_neg = sum((anchor .- negative).^2)
    return max(0, d_pos - d_neg + margin)
end


# ------------------------
# 5. Helper: get child program
# ------------------------
function get_child_program(program)
    if isempty(program.children)
        return nothing
    else
        # pick first child for simplicity
        return program.children[1]
    end
end


# ------------------------
# 6. Generate data from BFS
# ------------------------
benchmark       = HerbBenchmarks.String_transformations_2020
problem_grammar = get_all_problem_grammar_pairs(benchmark)[102]
problem         = problem_grammar.problem
spec            = [problem.spec[1]]
grammar         = problem_grammar.grammar
iterator        = HerbSearch.BFSIterator(grammar, :Start, max_depth=6)

println("Inputs")
println([example.in[:_arg_1].str for example in problem.spec])

println("\nDesired outputs")
println([example.out.str for example in problem.spec])

explored_programs = []

for (i, program) in enumerate(iterator)
    anchor_outputs = nothing

    try
        anchor_outputs = [benchmark.interpret(program, grammar, example).str for example in spec]
    catch BoundsError
        continue
    end


    push!(explored_programs, deepcopy(program))

    child_program = get_child_program(program)
    if isnothing(child_program)
        continue
    end

    # pick unrelated program randomly from explored programs
    unrelated_program = rand(explored_programs)

    # println("\nIteration $i")
    # println("Program $program")
    # println("Related $child_program")
    # println("Unrelated $unrelated_program")

    # compute outputs
    pos_outputs    = [benchmark.interpret(child_program, grammar, example).str for example in spec]
    neg_outputs    = [benchmark.interpret(unrelated_program, grammar, example).str for example in spec]

    # println("Program outputs $anchor_outputs")
    # println("Related outputs $pos_outputs")
    # println("Unrelated outputs $neg_outputs")

    # embeddings
    anchor_emb = program_embedding(anchor_outputs)
    pos_emb    = program_embedding(pos_outputs)
    neg_emb    = program_embedding(neg_outputs)

    # train
    loss = train_step!(anchor_emb, pos_emb, neg_emb)
end


function most_similar(target, candidates)
    target_embedding = program_embedding([target])
    embeddings_list = [program_embedding([candidate]) for candidate in candidates]

    similarities = [dot(target_embedding, e) / (norm(target_embedding) * norm(e)) for e in embeddings_list]

    for (candidate, similarity) in zip(candidates, similarities)
        println("$candidate $similarity")
    end

    max_index = argmax(similarities)
    return max_index, similarities[max_index]
end

target = "Puma"
candidates = ["2005 Ford Puma", "005 Ford Puma", "05 Ford Puma", "5 Ford Puma", "Ford Puma", "ord Puma", " Puma"] 

# println(most_similar(target, candidates))
most_similar(target, candidates)