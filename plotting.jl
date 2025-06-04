using Glob
using Plots

# File matching pattern
path_to_folder = "results/"
files = glob(joinpath(path_to_folder, "P_*_Frac_*_K-*_t_*.txt"))

# Data structure: Dict{String, Vector{Tuple{Int, Int, Int, Int, Bool}}}
# benchmark => list of (timeout, result, k, run, optimal)
data = Dict("strings" => [], "robots" => [], "pixels" => [])

# Regex to extract data from file contents
pattern = "Cost is Any\\[-(\\d+)\\]\\s+Optimal: (true|false)"
content_re = Regex(pattern, "s")

# Parse files
for file in files
    # Extract metadata from filename
    match = Base.match(r"P_(\w+)_Frac_(\d+)_K-(\d+)_t_(\d+)_", file)
    if match === nothing
        @warn "Could not parse filename: $file"
        continue
    end
    benchmark, run, k, timeout = match.captures
    run = parse(Int, run)
    k = parse(Int, k)
    timeout = parse(Int, timeout)

    # Read and parse content
    content = read(file, String)
    m = Base.match(content_re, content)
    if m === nothing
        @warn "Could not parse content in: $file"
        continue
    end
    result = parse(Int, m.captures[1])
    optimal = m.captures[2] == "true"

    push!(data[benchmark], (timeout, result, k, run, optimal))
end

# Color
ks = [1, 2, 4, 8, 16]
runs = 1:5

# Base RGB colors for each k (as tuples of 0-1 floats)
base_colors = Dict(
    1 => (0.0, 0.2, 1.0),   # strong blue
    2 => (0.0, 0.8, 0.3),   # vivid green
    4 => (1.0, 0.5, 0.0),   # bright orange
    8 => (0.6, 0.0, 0.8),   # strong purple
    16 => (1.0, 0.0, 0.2)   # bold red
)

# Generate color map by shading the base color towards white
color_map = Dict{Tuple{Int, Int}, RGB}()

for k in ks
    base = base_colors[k]
    for (i, run) in enumerate(runs)
        # weight closer to white (1.0, 1.0, 1.0) as run increases
        α = (i - 1) / (length(runs) - 1) * 0.7  # 0.0 to 1.0
        r = base[1] * (1 - α) + 1.0 * α
        g = base[2] * (1 - α) + 1.0 * α
        b = base[3] * (1 - α) + 1.0 * α
        color_map[(k, run)] = RGB(r, g, b)
    end
end

existing_points = Set()

# Plotting
for (benchmark, entries) in data
    plt = plot(xlabel="Timeout (s)", ylabel="Result (Cost)",
               title="Results for $benchmark", xscale=:log10, legend=:outertopright)

    for k in ks, run in runs
        pts = filter(e -> e[3] == k && e[4] == run, entries)

        for e in pts
            push!(existing_points, (benchmark, run, k, e[1]))
        end

        if !isempty(pts)
            timeouts = [e[1] for e in pts]
            results = [e[2] for e in pts]
            optimal_flags = [e[5] for e in pts]
            c = color_map[(k, run)]

            # Prepare marker colors: filled if optimal, white if not
            shapes = [optimal ? :square : :circle for optimal in optimal_flags]

            # Plot actual data WITHOUT label (so no legend entry)
            scatter!(timeouts, results,
                label = "",
                marker = shapes,
                markersize = 4,
                markercolor = c,
                markerstrokecolor=:transparent,
                markerstrokewidth=0)

            # Add one invisible point just for the legend with default filled circle
            scatter!([NaN], [NaN],
                label = "K=$k, run=$run",
                marker = :circle,
                markersize = 4,
                markercolor = c,
                markerstrokecolor=:transparent,
                markerstrokewidth=0)
        end
    end

    savefig(plt, "plots/$(benchmark)_results_plot.png")
    display(plt)
end

needed_points = Set([(b, r, k, t) for b in ["strings", "robots", "pixels"], r in [1,2,3,4,5], k in [1,2,4,8], t in [60,300,600,1800,3600,7200]])
missing_entries = filter!(e -> e ∉ existing_points, needed_points)
println(missing_entries)