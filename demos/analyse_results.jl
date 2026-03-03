using JSON

function analyse(benchmark_name)
    filename = "demos/results/$benchmark_name.json"
    data = isfile(filename) ? JSON.parsefile(filename) : Any[]

    solved = 0
    trivial = 0
    total = length(data)

    problems_solved = []
    problems_unsolved = []

    for result in data
        if result["solved"]
            push!(problems_solved, result["problem"]["name"])
            solved += 1
        else
            push!(problems_unsolved, result["problem"]["name"])
        end

        if length(result["properties"]) == 0
            trivial += 1
        end
    end

    println("Solved $solved of $total, of which $trivial trivial")
    @show problems_solved
    @show problems_unsolved
end

analyse("SyGuS strings")