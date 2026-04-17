using Pkg
Pkg.activate(".")
Pkg.add(PackageSpec(url="https://github.com/Herb-AI/HerbBenchmarks.jl.git"))
Pkg.instantiate()

# include("src/HerbSearch.jl")
include("ext/ThesisStef/program_heuristic.jl")

embed_dim = parse(Int, ARGS[1])
hidden_dim = parse(Int, ARGS[2])
filename = "embed_dim=$embed_dim,hidden_dim=$hidden_dim"

execute_experiment(;
    experiment_name = "model_size",
    filename = filename,
    repetitions = 1,#10,
    problem_ids = 1:8,#1:100,#2:6,#1:100,
    example_ids = 1:5,
    amount_of_programs_exploration = 50,
    max_size_exploration = 7,
    learning_rate = 0.04,
    amount_of_programs_explotation = 150,
    max_size_explotation = 10,
    model = "Embed -> GRU",
    embed_dim = embed_dim,
    hidden_dim = hidden_dim,
)

data = load_data("model_size", [filename])
display_results(data)
