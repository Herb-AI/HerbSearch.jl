"""
Formatting script inspired by that of the `Flux.jl` package, which
can be found at:
https://github.com/FluxML/Flux.jl/blob/caa1ceef9cf59bd817b7bf5c94d0ffbec5a0f32c/dev/flux_format.jl
"""

using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

using JuliaFormatter

help = """
Usage: herb_format [flags] [FILE/PATH]...
Formats the given julia files using the Herb formatting options.
If paths are given instead, it will format all *.jl files under
the paths. If nothing is given, all changed julia files are formatted.
    -v, --verbose
        Print the name of the files being formatted with relevant details.
    -h, --help
        Print this help message.
    --check
        Check if the files are formatted without changing them.
"""

options = Dict{Symbol, Bool}()
indices_to_remove = []      # used to delete options once processed

for (index, arg) in enumerate(ARGS)
    if arg[1] != '-'
        continue
    end
    val = true
    if arg in ["-v", "--verbose"]
        opt = :verbose
        push!(indices_to_remove, index)
    elseif arg in ["-h", "--help"]
        opt = :help
        push!(indices_to_remove, index)
    elseif arg == "--check"
        opt = :overwrite
        val = false
        write(stdout, "Checking files.\n")
        push!(indices_to_remove, index)
    else
        error("Option $arg is not supported.")
    end
    options[opt] = val
end

# remove options from args
deleteat!(ARGS, indices_to_remove)

# print help message if asked
if haskey(options, :help)
    write(stdout, help)
    exit(0)
end

# otherwise format files
if isempty(ARGS)
    filenames = readlines(`git ls-files "*.jl"`)
else
    filenames = ARGS
end

write(stdout, "Formatting in progress.\n")
# format returns true if the files were already formatted
# and false if they were not (had to be formatted)
exit(format(filenames; options...) ? 0 : 1)
