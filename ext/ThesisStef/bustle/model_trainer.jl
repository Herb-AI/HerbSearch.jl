using HerbCore, HerbGrammar, HerbConstraints, HerbBenchmarks, HerbSearch, HerbSpecification
using MLStyle, Flux, Statistics, JLD2

include("string_domain.jl")
include("property_signature.jl")
include("data_generation.jl")

data = generate_training_data_no_observation_equivalence(
    n_inputs_per_search = 5, 
    n_searches = 100,#1000
    n_expressions_per_search = 1_000, #100_000
    n_selections = 1#100
)

model = Chain(
    Dense(76 => 2 * 76),
    Dense(2 * 76 => 1),
)

loss(m, x, y) = Flux.mse(y, m(x))

training_loss(m) = sum(loss(m, x, y) for (x, y) in data)

l = training_loss(model)
println("Initial loss is $l")
opt_state = Flux.setup(Adam(), model)

for n in 1:5
    Flux.train!(loss, model, data, opt_state)
    l = training_loss(model)
    println("Loss after iteration $n is $l")
end

model_state = Flux.state(model)
jldsave("bustle.jld2", model_state)