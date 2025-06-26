using DataFrames, Plots, StatsBase


function parse_result_file(filename)
    # path = "experiments/results_strings/graph"
    # size = 326

    path = "experiments/results_bitvectors"
    size = 468

    lines = readlines("$path/$filename")
    results = DataFrame(problem=String[], solved=Bool[], duration=Float64[],
                        iterations=Int[], tree_size=Int[], cost=Int[], program=String[])
    for line in lines[1:size]
        m = match(r"problem:\s*([^,]+), solved:\s*(\w+), duration:\s*([\d.]+), iterations:\s*(\d+), tree_size:\s*(\d+), cost:\s*(\d+), program:\s*(.*)", line)
        if m !== nothing
            push!(results, (
                m[1], m[2] == "true", parse(Float64, m[3]), parse(Int, m[4]),
                parse(Int, m[5]), parse(Int, m[6]), m[7]
            ))
        end
    end
    return results
end

filenames = Dict("Baseline" => "baseline.txt", "K = 1" => "k=1.txt", "K = 2" => "k=2.txt", "K = 4" => "k=4.txt")
all_results = Dict(k => parse_result_file(v) for (k, v) in filenames)


function amount_solved()
    order = ["Baseline", "K = 1", "K = 2", "K = 4"]
    baseline_df = all_results["Baseline"]
    baseline_dict = Dict(row.problem => row.solved for row in eachrow(baseline_df))

    shared_counts = Int[]
    extra_counts = Int[]

    for k in order
        k_df = all_results[k]

        shared = 0
        extra = 0

        for row in eachrow(k_df)
            prob = row.problem
            if row.solved
                if get(baseline_dict, prob, false)
                    shared += 1
                elseif k != "Baseline"
                    extra += 1
                end
            end
        end

        push!(shared_counts, shared)
        push!(extra_counts, extra + shared)
    end

    y = [extra_counts, shared_counts]

    bar(order,
        y,  # converts y to a tuple of columns
        label=["Not solved by baseline" "Solved by baseline"],
        xlabel="Amount of compressions",
        ylabel="Solved problems",
        title="Solved problems compared to baseline",
        legend=:topleft,
        bar_position=:stack,
        ylims=(0, 60),
        color=[:lightgreen :lightblue])
end



function iterations_1() 
    order = ["Baseline", "K = 1", "K = 2", "K = 4"]
    plots = []

    for label in order
        df = all_results[label]
        sorted_idx = sortperm(df.iterations)
        sorted_iterations = df.iterations[sorted_idx]
        sorted_solved = df.solved[sorted_idx]
        colors = map(s -> s ? :green : :gray, sorted_solved)

        p = bar(1:length(sorted_iterations), sorted_iterations,
                color=colors,
                xlabel="Problems (sorted)",
                ylabel="Iterations",
                title="Iterations per solved problem — $label",
                ylims=(0, 50000))
        push!(plots, p)
    end

    plot(plots..., layout=(2, 2), size=(1000, 800))
end

function iterations()
    order = ["Baseline", "K = 1", "K = 2", "K = 4"]
    baseline_df = all_results["Baseline"]
    baseline_dict = Dict(row.problem => row.solved for row in eachrow(baseline_df))

    plots = []

    for label in order
        df = all_results[label]
        sorted_idx = sortperm(df.iterations)
        sorted_iterations = df.iterations[sorted_idx]
        sorted_problems = df.problem[sorted_idx]
        sorted_solved = df.solved[sorted_idx]

        colors = Symbol[]
        for (prob, solved) in zip(sorted_problems, sorted_solved)
            if solved
                if get(baseline_dict, prob, false)
                    push!(colors, :lightblue)
                else
                    push!(colors, :lightgreen)
                end
            else
                push!(colors, :gray)
            end
        end

        p = bar(1:length(sorted_iterations), sorted_iterations,
                color=colors,
                xlabel="Problems (sorted)",
                ylabel="Iterations",
                title="Iterations per solved problem — $label",
                label="",
                ylims=(0, 8000),
                legend=:topleft)  # only here, not below!

        # Add dummy bars only once with explicit labels
        plot!(p, [], []; color=:lightgreen, label="Solved only by $label", seriestype=:bar)
        plot!(p, [], []; color=:lightblue, label="Also solved by Baseline", seriestype=:bar)

        push!(plots, p)
    end

    plot(plots..., layout=(2, 2), size=(1000, 800))
end


function durations()
    order = ["Baseline", "K = 1", "K = 2", "K = 4"]
    baseline_df = all_results["Baseline"]
    baseline_dict = Dict(row.problem => row.solved for row in eachrow(baseline_df))

    plots = []

    for label in order
        df = all_results[label]
        sorted_idx = sortperm(df.duration)
        sorted_iterations = df.duration[sorted_idx]
        sorted_problems = df.problem[sorted_idx]
        sorted_solved = df.solved[sorted_idx]

        colors = Symbol[]
        for (prob, solved) in zip(sorted_problems, sorted_solved)
            if solved
                if get(baseline_dict, prob, false)
                    push!(colors, :lightblue)
                else
                    push!(colors, :lightgreen)
                end
            else
                push!(colors, :gray)
            end
        end

        p = bar(1:length(sorted_iterations), sorted_iterations,
                color=colors,
                xlabel="Problems (sorted)",
                ylabel="Duration (s)",
                title="Duration per solved problem — $label",
                label="",
                ylims=(0, 6),
                legend=:topleft)  # only here, not below!

        # Add dummy bars only once with explicit labels
        plot!(p, [], []; color=:lightgreen, label="Solved only by $label", seriestype=:bar)
        plot!(p, [], []; color=:lightblue, label="Also solved by Baseline", seriestype=:bar)

        push!(plots, p)
    end

    plot(plots..., layout=(2, 2), size=(1000, 800))
end


function treesizes()
    order = ["Baseline", "K = 1", "K = 2", "K = 4"]
    baseline_df = all_results["Baseline"]
    baseline_dict = Dict(row.problem => row.solved for row in eachrow(baseline_df))

    plots = []

    for label in order
        df = all_results[label]
        sorted_idx = sortperm(df.tree_size)
        sorted_iterations = df.tree_size[sorted_idx]
        sorted_problems = df.problem[sorted_idx]
        sorted_solved = df.solved[sorted_idx]

        colors = Symbol[]
        for (prob, solved) in zip(sorted_problems, sorted_solved)
            if solved
                if get(baseline_dict, prob, false)
                    push!(colors, :lightblue)
                else
                    push!(colors, :lightgreen)
                end
            else
                push!(colors, :gray)
            end
        end

        p = bar(1:length(sorted_iterations), sorted_iterations,
                color=colors,
                xlabel="Problems (sorted)",
                ylabel="Tree size",
                title="Tree size per solved problem — $label",
                label="",
                ylims=(0, 15),
                legend=:topleft)  # only here, not below!

        # Add dummy bars only once with explicit labels
        plot!(p, [], []; color=:lightgreen, label="Solved only by $label", seriestype=:bar)
        plot!(p, [], []; color=:lightblue, label="Also solved by Baseline", seriestype=:bar)

        push!(plots, p)
    end

    plot(plots..., layout=(2, 2), size=(1000, 800))
end


# amount_solved()
# iterations()
# durations()
treesizes()