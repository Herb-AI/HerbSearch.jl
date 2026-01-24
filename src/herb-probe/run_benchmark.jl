using JSON3
using HerbBenchmarks
using HerbBenchmarks.PBE_SLIA_Track_2019
using HerbSearch
using HerbCore
using HerbGrammar
using HerbSpecification
using HerbConstraints
using MLStyle

# --- listing + loading ---
function slia_problem_suffixes()::Vector{String}
    suffixes = String[]
    for nm in names(PBE_SLIA_Track_2019; all=true)
        s = String(nm)
        if startswith(s, "problem_")
            push!(suffixes, s[length("problem_")+1:end])
        end
    end
    # sort!(unique(suffixes))
    return unique(suffixes)
end

function load_slia(suffix::String)
    psym = Symbol("problem_", suffix)
    gsym = Symbol("grammar_", suffix)
    problem = getproperty(PBE_SLIA_Track_2019, psym)
    grammar = hasproperty(PBE_SLIA_Track_2019, gsym) ?
        getproperty(PBE_SLIA_Track_2019, gsym) :
        error("No matching grammar for suffix=$suffix")
    return grammar, problem
end

function chunk_bounds(n::Int, chunk_size::Int, chunk_index::Int)
    lo = (chunk_index - 1) * chunk_size + 1
    hi = min(chunk_index * chunk_size, n)
    lo > n && error("CHUNK=$chunk_index out of range (n=$n, chunk_size=$chunk_size)")
    return lo, hi
end

# --- run one problem (you plug in your method here) ---
function run_one_problem(suffix::String; attempts::Int=3, max_enum::Int=10_000)
    grammar, problem = load_slia(suffix)

    eval(make_interpreter(grammar))
    tags = HerbBenchmarks.get_relevant_tags(grammar)

    iter0 = MLFSIterator(grammar, :ntString)

    synth_fn = create_probe_synth_fn(
        interpret, tags;
        maximum_enumerations = max_enum,
        maximum_time = typemax(Int),
    )

    updater = create_probe_updater(MLFSIterator, :ntString)

    ctrl = BudgetedSearchController(
        problem = problem,
        iterator = iter0,
        synth_fn = synth_fn,
        stop_checker = probe_stop_checker,
        attempts = attempts,
        selector = probe_selector,
        updater = updater,
    )

    results, times, total, probabilities, selected_prom_prog = run_budget_search(ctrl)

    solved = any(res -> res[2] == optimal_program, results)

    # best fitness + attempt
    best_f = 0.0
    best_fs = []
    # best_f_probs = []
    best_att = 0
    prom_progs = []
    for (att, res) in enumerate(results)
        promising = res[1]
        push!(prom_progs, length(promising))
        if !isempty(promising)
            (r, f) = reduce((a,b)->(a[2] >= b[2] ? a : b), promising)
            if f > best_f
                best_f = float(f)
                best_att = att
            end
            push!(best_fs, f)
            # push!(best_f_probs, max_rulenode_log_probability(r, grammar))
        end
    end

    return (
        suffix = suffix,
        solved = solved,
        best_fitness_per_cycle = best_fs,
        best_fitness = best_f,
        best_attempt_cycle = best_att,
        attempts_run = length(results),
        promising_programs = prom_progs,
        selected_prom_progs = selected_prom_prog,
        # best_rulenode_log_probabilities = best_f_probs,
        times = times,
        total_time = total,
        max_enum = max_enum,
        probabilities_grammar = probabilities,
    )
end

# --- main chunk driver ---
suffixes = slia_problem_suffixes()
n = length(suffixes)

chunk_size = parse(Int, get(ENV, "CHUNK_SIZE", "3"))
chunk = parse(Int, get(ENV, "CHUNK", "1"))
(lo, hi) = chunk_bounds(n, chunk_size, chunk)
my_suffixes = suffixes[lo:hi]

attempts = parse(Int, get(ENV, "ATTEMPTS", "3"))
max_enum  = parse(Int, get(ENV, "MAX_ENUM", "1000"))

out_path = get(ENV, "OUT", "slia_probe_chunk$(chunk)_$(lo)-$(hi).jsonl")

println("Running chunk=$chunk indices $lo-$hi (", length(my_suffixes), " problems)")
println("Writing to $out_path")

open(out_path, "w") do io
    problems_completed = 0
    for suf in my_suffixes
        row = try
            run_one_problem(suf; attempts=attempts, max_enum=max_enum)
        catch err
            (suffix=suf, error=string(err))
        end
        JSON3.write(io, row)
        write(io, "\n")
        flush(io)
        problems_completed = problems_completed + 1
        println("Completed ", problems_completed, "/", length(my_suffixes), " problems.")
    end
end

println("Finished writing to $out_path")

