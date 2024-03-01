using HerbInterpret
using HerbGrammar
using HerbSpecification
using HerbSearch
using Logging
using Statistics

include("meta_runner.jl")
include("run_algorithm.jl")


Logging.disable_logging(Logging.LogLevel(1))


output = run_meta_search((current_time, i, fitness) -> current_time > 1)

println("Output of meta search is: ", output)
#=
using PlotlyJS
b = box(;y = global_runs, name="MH"); plot(b)
=#
