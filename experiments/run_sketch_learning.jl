#!/usr/bin/env julia
# run_sketch_learning.jl
#

using HerbGrammar
using HerbCore
using HerbSpecification
using HerbSearch
using HerbBenchmarks
using HerbBenchmarks.PBE_SLIA_Track_2019
# using HerbBenchmarks.PBE_BV_Track_2018
using CSV
using DataFrames
using DataStructures
using Dates
using MLStyle
using Logging


function print_progress(current, total, start_time)
    elapsed = round(DateTime(now()) - start_time, Dates.Second)
    print("\rProgress: $(current)/$(total)  |  Elapsed: $elapsed")
    flush(stdout)
end

general_iterator_factories = Dict(
    "SizeBased" => (g, start; kwargs...) ->
        SizeBasedBottomUpIterator(g, start; kwargs...), "DepthBased" => (g, start; kwargs...) ->
        DepthBasedBottomUpIterator(g, start; kwargs...), "CostBased" => (g, start; kwargs...) -> begin
        g2 = isprobabilistic(g) ? g : init_probabilities!(g)
        costs = HerbSearch.get_costs(g2)
        CostBasedBottomUpIterator(
            g2, start;
            current_costs=costs,
            kwargs...
        )
    end
)

########################
# HELPERS 
########################

function mask_similarity(mask1::UInt64, mask2::UInt64)
    inter = count_ones(mask1 & mask2)
    s1 = count_ones(mask1)
    s2 = count_ones(mask2)
    return (s1 == 0 || s2 == 0) ? 0.0 : inter / sqrt(s1 * s2)
end

function log_pattern_and_rule(logline, patt, grammar)
    logline("Pattern found: $(patt)")
    logline("----------------")
end

pattern_for = function (selected, grammar)

    anti_unify_programs(selected, grammar;
        min_nonholes=0,
        max_holes=20
    )
end

########################
# OBSERVATIONAL EQUIVALENCE
########################

function hash_outputs_to_u64vec(outs_any::Vector{<:Any})
    sig = Vector{UInt64}(undef, length(outs_any))
    @inbounds for i in eachindex(outs_any)
        sig[i] = hash(outs_any[i], 0x9d1c43f52d7a01ff)
    end
    return sig
end

function program_output_signature(
    prog::AbstractRuleNode,
    grammar,
    problem
)
    outputs = Vector{Any}(undef, length(problem.spec))

    grammar_tags = get_relevant_tags(grammar)

    for (i, ex) in enumerate(problem.spec)
        try
            outputs[i] = interpret_sygus_fn(prog, grammar_tags, ex.in)
        catch e
            println("EVAL ERROR: ", e)
            outputs[i] = :__ERROR__
        end
    end
    return hash_outputs_to_u64vec(outputs)
end

function dedup_by_outputs(
    progs_with_masks,
    grammar,
    problem,
    logline
)
    seen = Dict{Vector{UInt64}, Tuple{AbstractRuleNode, Float64, UInt64}}()
    removed = 0

    for (prog, score, mask) in progs_with_masks
        sig = program_output_signature(prog, grammar, problem)


        if haskey(seen, sig)
            removed += 1
        else
            seen[sig] = (prog, score, mask)
        end
    end

    if removed > 0
        logline("Observational equivalence removed $removed programs")
    end

    return collect(values(seen))
end

function root_rule(prog::AbstractRuleNode)
    if prog isa RuleNode
        return get_rule(prog)   # Int or Symbol (grammar rule index)
    elseif prog isa UniformHole
        return :HOLE
    else
        return :UNKNOWN
    end

end

function group_by_root(progs_with_masks)
    groups = Dict{Any, Vector{Tuple{AbstractRuleNode, Float64, UInt64}}}()

    for triple in progs_with_masks
        prog = triple[1]
        r = root_rule(prog)
        push!(get!(groups, r, Vector()), triple)
    end

    return groups
end



########################
# BUDGETED HELPERS 
########################


function cluster_by_mask(similar_threshold::Float64, progs_with_masks, grammar, logline)
    clusters = Vector{Vector{Tuple{AbstractRuleNode,UInt64}}}()

    for (prog, score, mask) in progs_with_masks

        placed = false

        for cluster in clusters
            # Compare with first program in cluster
            (_, rep_mask) = cluster[1]

            if mask_similarity(mask, rep_mask) ≥ similar_threshold
                push!(cluster, (prog, mask))
                placed = true
                break
            end
        end

        if !placed
            push!(clusters, [(prog, mask)])
        end
    end

    return clusters
end

function choose_selector(selector_type, empty_selector, all_selector, cluster_selector, root_selector, root_cluster_selector)
    if selector_type == "empty"
        return empty_selector
    elseif selector_type == "all"
        return all_selector
    elseif selector_type == "cluster"
        return cluster_selector
    elseif selector_type == "root"
        return root_selector
    elseif selector_type == "root_cluster"
        return root_cluster_selector
    else
        error("Unknown selector_type: $selector_type")
    end
end

############################################################
# MAIN FUNCTION
############################################################
function run_experiment(
    run_id;
    run_prefix="baseline_run",
    iterator_type="SizeBU",
    max_iterator_depth=10,
    max_enumerations=10000,
    selection_criteria=0.2,
    budgeted_search_attempts=1,
    allow_evaluation_errors=true,
    stop_when_found=true,
    max_program_size=15,
    max_cost=20.0,
    cluster_similarity_threshold=0.8,
    selector_type="cluster"
)

    budgeted_iteration = 0


    ### Make directories
    run_dir = joinpath(
            "experiment_results",
            run_prefix,
            "$(run_prefix)_$(run_id)"
    )
    isdir(run_dir) || mkpath(run_dir)

    println("FILE: ", run_dir)
    flush(stdout)

    logfile = joinpath(run_dir, "sketch_learning_log.txt")
    log_io = open(logfile, "w")

    learned_file = joinpath(run_dir, "learned_frules.txt")
    summary_file = joinpath(run_dir, "results_summary.csv")


    # LOG_BUFFER = IOBuffer()

    
    # logline(msg) = println(LOG_BUFFER, "[$(Dates.now())] $msg")
    # logline(msg) = @info msg

    logline(msg) = begin
        println(log_io, "[$(Dates.now())] $msg")
        flush(log_io)
    end

    # Record experiment setup
    logline("=== Experiment Run $run_id ===")
    logline("iterator_type = $iterator_type")
    logline("max_iterator_depth = $max_iterator_depth")
    logline("max_enumerations = $max_enumerations")
    logline("selection_criteria = $selection_criteria")
    logline("attempts = $budgeted_search_attempts")
    logline("max_program_size = $max_program_size")
    logline("max_cost = $max_cost")
    logline("cluster_similarity_threshold = $cluster_similarity_threshold")
    logline("selector_type = $selector_type")

    # Load all benchmarks (skip first)
    allpairs_all = HerbBenchmarks.get_all_problem_grammar_pairs(
        HerbBenchmarks.PBE_SLIA_Track_2019
    )[2:end]

    chunk_size = 20
    start_idx = (run_id - 1) * chunk_size + 1
    end_idx = min(run_id * chunk_size, length(allpairs_all))

    if start_idx > length(allpairs_all)
        error("run_id=$run_id out of range, only $(length(allpairs_all)) problems available")
    end

    allpairs = allpairs_all[start_idx:end_idx]

    println("Processing problems [$start_idx:$end_idx] out of $(length(allpairs_all))")
    logline("Processing problems [$start_idx:$end_idx] out of $(length(allpairs_all))")

    ########################
    # BUDGETED FUNCTIONS 
    ########################

    stop_checker = sol -> begin
        optimal = sol.value[2]
        exhausted = (sol.value[3] === nothing)

        if optimal || exhausted
            println("stop_checker: stopping because ",
                    optimal ? "optimal_found == true" : "final_state == nothing")
        end

        return optimal || exhausted
    end

    update_solution = function (timed_solution, best_solution, best_score, best_program_enumeration_step)
        budgeted_iteration += 1
        logline("BUDGETED ITERATION  $(budgeted_iteration)")
        new_best_score = timed_solution.value[4]
        new_best_program_enumeration_step = timed_solution.value[6] + (budgeted_iteration-1) * 10000

        if best_score === nothing
            best_score = -Inf
        end

        if new_best_score > best_score
            best_score = new_best_score
            best_solution = timed_solution.value[5]
            best_program_enumeration_step = new_best_program_enumeration_step

            logline("⟹ New best score = $new_best_score")
            logline("   Program: $(best_solution)")
            logline("⟹ Enumeration step = $best_program_enumeration_step")
        end

        return best_solution, best_score, best_program_enumeration_step
    end

    empty_selector = (results, iterator, problem) -> begin
        return AbstractRuleNode[]
    end

    all_selector = (results, iterator, problem) -> begin
        programs = AbstractRuleNode[]
        grammar = iterator.solver.grammar

        for (prog, score, mask) in results[1]

            push!(programs, prog)
            expr = rulenode2expr(prog, grammar)
        end

        logline("Number of programs selected = $(length(programs))")
        patt = pattern_for(programs, grammar)
        if patt === nothing
            logline("No pattern produced (nothing). Skipping.")
            return AbstractRuleNode[]
        end
        log_pattern_and_rule(logline, patt, grammar)
        new_programs = AbstractRuleNode[patt]
        return new_programs
    end

    cluster_selector = (results, iterator, problem) -> begin

        grammar = iterator.solver.grammar

        learned_programs = AbstractRuleNode[]
        if length(results[1]) == 0
            logline("No candidate programs")
            return learned_programs
        end

        raw = results[1]
        logline("Number of candidate programs = $(length(raw))")

        t = @elapsed begin
            clusters = cluster_by_mask(cluster_similarity_threshold, results[1], grammar, logline)
        end
        println("CLUSTERING took $(round(1000t, digits=2)) ms")
        flush(stdout)
        logline("Clusters found = $(length(clusters))")

        learned_programs = AbstractRuleNode[]


        for (i, cluster) in enumerate(clusters)
            logline("Cluster $i size = $(length(cluster))")

            if length(cluster) < 2
                logline("Cluster $i too small, skipping.")
                continue
            end

            # Extract only program nodes (ignore masks)
            programs = AbstractRuleNode[first(t) for t in cluster]

            t = @elapsed begin
                patt = pattern_for(programs, grammar)
            end
            println("ANTI-UNIFICATION (cluster size=$(length(programs))) took $(round(1000t, digits=2)) ms")
            flush(stdout)


            if patt === nothing
                logline("Cluster $i → no pattern")
                continue
            end

            log_pattern_and_rule(logline, patt, grammar)
            push!(learned_programs, patt)
        end

        return learned_programs
    end

    root_selector = (results, iterator, problem) -> begin
        grammar = iterator.solver.grammar
        learned_programs = AbstractRuleNode[]

        raw = results[1]
        if length(raw) == 0
            logline("No candidate programs")
            return learned_programs
        end
        isempty(raw) && return learned_programs

        logline("Number of candidate programs = $(length(raw))")

        groups = group_by_root(raw)
        logline("Root groups = $(length(groups))")

        for (root, group) in groups
            logline("Root $root → $(length(group)) programs")

            # extract programs only
            programs = AbstractRuleNode[prog for (prog, _, _) in group]

            # skip trivial groups
            length(programs) < 2 && continue

            t = @elapsed begin
                patt = pattern_for(programs, grammar)
            end

            println("ANTI-UNIFICATION (root=$root, n=$(length(programs))) took $(round(1000t, digits=2)) ms")
            flush(stdout)

            if patt === nothing
                logline("Root $root → no pattern")
                continue
            end

            log_pattern_and_rule(logline, patt, grammar)
            push!(learned_programs, patt)
    end

    return learned_programs
end

   root_cluster_selector = (results, iterator, problem) -> begin
        grammar = iterator.solver.grammar
        learned = AbstractRuleNode[]

        raw = results[1]
        isempty(raw) && return learned

        logline("Candidates = $(length(raw))")

        # 1. Group by root
        groups = group_by_root(raw)
        logline("Root groups = $(length(groups))")

        for (root, group) in groups
            logline("Root $root → $(length(group)) programs")

            length(group) < 2 && continue

            # 2. Cluster within root
            t = @elapsed begin
                clusters = cluster_by_mask(
                    cluster_similarity_threshold,
                    group,
                    grammar,
                    logline
                )
            end
            println("ROOT $root: clustering took $(round(1000t, digits=2)) ms")
            flush(stdout)

            for (i, cluster) in enumerate(clusters)
                logline("  Cluster $i size = $(length(cluster))")

                length(cluster) < 2 && continue

                programs = AbstractRuleNode[first(t) for t in cluster]

                # Optional: cap AU cost
                length(programs) > 20 && (programs = programs[1:20])

                t = @elapsed begin
                    patt = pattern_for(programs, grammar)
                end
                println(
                    "ANTI-UNIFICATION (root=$root, cluster=$i, n=$(length(programs))) " *
                    "took $(round(1000t, digits=2)) ms"
                )
                flush(stdout)

                patt === nothing && continue

                log_pattern_and_rule(logline, patt, grammar)
                push!(learned, patt)
            end
        end

        return learned
    end



    selector = choose_selector(selector_type, empty_selector, all_selector, cluster_selector, root_selector, root_cluster_selector)


    updater = function (selected, iterator)
        return iterator
    end

    extract_state = function(solution_value, sketches, iterator)
        state = solution_value[3]  

        for sketch in sketches
            @assert sketch isa AbstractRuleNode
            push!(state.sketches, sketch)
            logline("ADDED SKETCH: $(sketch)")
            println("ADDED SKETCH: $(sketch)")
        end



        t = @elapsed begin
            new_state = enqueue_sketch_expansions!(iterator, state)
        end

        println("SKETCH EXPANSION took $(round(1000t, digits=2)) ms")
        sketch_stats = print_sketch_stats()
        logline("TOTAL SKETCH GENERATED PROGRAMS $(sketch_stats)")

        hash_stats = print_hash_rejection_stats()
        logline("TOTAL SKETCH REJECTED BY HASH $(hash_stats)")
    
        flush(stdout)

        return iterator, new_state      
        HemijskaPise#123       
    end



    ########################
    # Summary DataFrame
    ########################
    df = DataFrame(
        problem_id=String[],
        solved=Bool[],
        best_score=Float64[],
        best_expr=String[],
        best_enumeration_step=Int[],
        attempt_times=Vector{Float64}[],
        total_time=Float64[],
    )

    start_time = now()

    for (idx, pgp) in enumerate(allpairs)

        budgeted_iteration = 0
        reset_sketch_counters!()


        print_progress(idx, length(allpairs), start_time)

        logline("\n===============================")
        logline("Benchmark problem $idx: $(pgp.identifier)")
        logline("===============================")


        problem = pgp.problem
        grammar = pgp.grammar
        start = :ntString

        iterator =
            if iterator_type == "BFS" || iterator_type == "BFSIterator"
                BFSIterator(grammar, start, max_depth=max_iterator_depth)

            elseif iterator_type in ("SizeBU", "SizeBasedBottomUpIterator")
                general_iterator_factories["SizeBased"](
                    grammar, start;
                    max_size=max_program_size,
                    max_depth=max_iterator_depth
                )

            elseif iterator_type in ("DepthBU", "DepthBasedBottomUpIterator")
                general_iterator_factories["DepthBased"](
                    grammar, start;
                    max_depth=max_iterator_depth
                )

            elseif iterator_type in ("CostBU", "CostBasedBottomUpIterator")
                general_iterator_factories["CostBased"](
                    grammar, start;
                    max_size=max_program_size,
                    max_depth=max_iterator_depth,
                    max_cost=max_cost

                )

            else
                error("Unknown iterator_type: $iterator_type")
            end


        synth_fn = function (problem, iterator; iterator_state=nothing)
            synth_multi_with_state(
                problem,
                iterator;
                iterator_state=iterator_state,
                selection_criteria=selection_criteria,
                max_enumerations=max_enumerations,
                allow_evaluation_errors=allow_evaluation_errors,
                stop_when_found=stop_when_found
            )
        end


        ctrl = BudgetedSearchController(
            problem=problem,
            iterator=iterator,
            synth_fn=synth_fn,
            attempts=budgeted_search_attempts,
            selector=selector,
            updater=updater,
            stop_checker=stop_checker,
            extract_state=extract_state,
            update_solution=update_solution,
        )


        best_solution, best_score, best_program_enumeration_step,  times, time_count = run_budget_search(ctrl)

        solved = (best_score == 1.0)
        best_expr_str = ""

        push!(
            df,
            (
                pgp.identifier,
                solved,
                best_score,
                best_expr_str,
                best_program_enumeration_step,
                times,        # vector of attempt times
                time_count    # total time
            )
        )

        sketch_stats = print_sketch_stats()
        logline("TOTAL SKETCH GENERATED PROGRAMS $(sketch_stats)")

        hash_stats = print_hash_rejection_stats()
        logline("TOTAL SKETCH REJECTED BY HASH $(hash_stats)")


        # # ---- FLUSH LOG EVERY 5 BENCHMARKS ----
        # if idx % 5 == 0
        #     open(logfile, "a") do f
        #         write(f, String(take!(LOG_BUFFER)))
        #     end
        # end
    end

    CSV.write(summary_file, df)

    # open(logfile, "a") do f
    #     write(f, String(take!(LOG_BUFFER)))
    # end


    return df
end


############################################################
# IF CALLED FROM TERMINAL
# (e.g. julia --project=. run_sketch_learning.jl 3)
############################################################
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia run_sketch_learning.jl <run_id>")
        exit()
    end
    run_id = parse(Int, ARGS[1])
    run_prefix = ARGS[2]
    println("Running experiment run_id=$run_id prefix=$run_prefix")
    run_experiment(run_id; run_prefix=run_prefix)
end

