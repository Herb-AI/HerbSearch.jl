using HerbCore, HerbGrammar, HerbConstraints, HerbBenchmarks, HerbSearch, HerbSpecification
using MLStyle, Flux, Statistics, JLD2, Random

include("string_domain.jl")
include("property_signature.jl")
include("data_generation.jl")

function run(embed_dim_facs, trial)
    input_dim = 76

    n_searches_train = 1000
    # n_searches_train = 10
    n_searches_test = 100
    # n_searches_test = 1
    n_searches = n_searches_train + n_searches_test
    n_selections = 100

    data = generate_training_data_no_observation_equivalence(
        n_inputs_per_search = 5, 
        n_searches = n_searches,
        n_expressions_per_search = 100_000,
        # n_expressions_per_search = 1_000,
        n_selections = n_selections,
    )

    train_data_length = 2 * n_searches_train * n_selections
    train_data = data[1:train_data_length]
    test_data = data[train_data_length + 1:end]

    @show length(data)
    @show length(train_data)
    @show length(test_data)

    X = [x for (x, y) in train_data]
    Y = [y for (x, y) in train_data]

    X_test = [x for (x, y) in test_data]
    Y_test = [y for (x, y) in test_data]

    results = Dict()

    for embed_dim_fac in embed_dim_facs
        embed_dim = Int(round(input_dim * embed_dim_fac))
        println("\nEmbedding dimension = $embed_dim")

        model = Chain(
            Dense(input_dim => embed_dim, tanh),
            Dense(embed_dim => 1, tanh),
            x -> x[1],
        )

        loss(m, Xi, Yi) = mean(abs2.(m.(Xi) .-  Yi))

        test_loss(m) = loss(m, X_test, Y_test)
        train_loss(m) = loss(m, X, Y)
        test_accuracy(m) = mean(round.(m.(X_test)) .== Y_test)

        initial_train_loss = train_loss(model)
        initial_test_loss = test_loss(model)
        initial_test_accuracy = test_accuracy(model)
        println("0: train = $initial_train_loss \t test = $initial_test_loss \t acc = $initial_test_accuracy")
        opt = Flux.setup(Adam(), model)

        loader = Flux.DataLoader((X, Y), batchsize = 100, shuffle = true)
        final_test_loss = nothing
        final_test_acc = nothing

        for n in 1:5
            for (Xi, Yi) in loader
                grads = Flux.gradient(model) do m
                    loss(m, Xi, Yi)
                end

                Flux.update!(opt, model, grads[1])
            end

            train_loss_i = train_loss(model)
            test_loss_i = test_loss(model)
            test_accuracy_i = test_accuracy(model)
            println("$n: train = $train_loss_i \t test = $test_loss_i, \t acc = $test_accuracy_i")

            final_test_loss = test_loss_i
            final_test_acc = test_accuracy_i
        end

        model_state = Flux.state(model)
        jldsave("ext/ThesisStef/bustle/models/bustle_embed=$(embed_dim)_trial=$(trial).jld2"; model_state)

        results[embed_dim_fac] = (final_test_loss, final_test_acc)
    end

    return results
end

results = Dict()
embed_dim_facs = [0.01, 0.02, 0.05, 0.1, .25]
trials = [1, 2, 3, 4, 5]

for trial in trials
    results[trial] = run(embed_dim_facs, trial)
end

for embed_dim_fac in embed_dim_facs
    println()
    losses = []
    accs = []
    embed_dim = Int(round(embed_dim_fac * 76))

    for trial in trials
        (loss, acc) = results[trial][embed_dim_fac]
        push!(losses, loss)
        push!(accs, acc)
        println("$embed_dim_fac * 76 = $embed_dim \t\t $trial \t\t $loss \t\t $acc")
    end

    ml = mean(losses)
    sl = std(losses)
    ma = mean(accs)
    sa = std(accs)

    println("$embed_dim_fac * 76 = $embed_dim \t Loss: mean = $ml \t std = $sl")
    println("$embed_dim_fac * 76 = $embed_dim \t Acc:  mean = $ma \t std = $sa")
end
