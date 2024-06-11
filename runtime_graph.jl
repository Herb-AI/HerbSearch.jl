using JSON

draw_edges = false
colours = ["blue!30", "red!30", "gray!40", "green!35", "violet!50", "orange!30"]

cd("experiments")

experiment_dirs = readdir()

n = length(experiment_dirs)

# list of (seed, avg_time, sd) tuples per experiment
experiments = Vector{Vector{Tuple{Int,Float64,Union{String,Float64}}}}(undef, n)

seeds = Set()

for experiment_dir in experiment_dirs
    experiment_number = parse(Int, split(experiment_dir, "_")[2])
    experiments[experiment_number] = []
    for file in readdir(experiment_dir)
        data = JSON.parsefile("$experiment_dir/$file")

        avg_time = data["avg_time"]
        push!(experiments[experiment_number], (data["world"]["seed"], typeof(avg_time) <: Number ? avg_time : 0.0, data["standard_deviation"]))
        push!(seeds, data["world"]["seed"])
    end
end

println("""\\begin{figure*}
\\centering
\\begin{tikzpicture}[trim axis left, trim axis right]
\\begin{axis}[
    ybar, axis on top,
    ymajorgrids, tick align=inside,
    major grid style={draw=black!15},
    enlarge y limits={value=.1,upper},
    ymin=0, ymax=600,
    ytick distance={100},
    axis x line*=bottom,
    axis y line*=left,
    y axis line style={opacity=0},
    tickwidth=0pt,
    legend style={
        at={(0.5,-0.2)},
        anchor=north,
        legend columns=-1,
    },
    legend image code/.code={
        \\draw [#1] (0cm,-0.1cm) rectangle (0.2cm,0.25cm); },
    ylabel={Time (s)},
    xlabel={World seed},
    symbolic x coords={$(join(sort(collect(seeds)), ","))},
    xtick=data,
    ]""")

for i in 1:n
    println("    \\addplot[fill=$(colours[i])$(draw_edges ? "" : ",$(colours[i])"),error bars/.cd,y dir=both,y explicit, error bar style={color=black}] coordinates { % experiment $i")
    for point in experiments[i]
        println("        ($(point[1]), $(point[2]))$(typeof(point[3]) <: Number ? " +- (0, $(point[3]))" : "")")
    end
    println("    };")
end

println("    \\legend{$(join(["Experiment $i" for i in 1:n], ","))}")

println("""\\end{axis}
\\end{tikzpicture}
\\caption{Average execution time of the experiments over three runs in seconds. A missing bar means that the experiment timed out for at least one run. The graph also shows the standard deviation of each experiment.}
\\label{fig:experiment-time}
\\end{figure*}""")
