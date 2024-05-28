"""
    mutable struct TopDownIterator <: ProgramIterator 

Enumerates a context-free grammar starting at [`Symbol`](@ref) `sym` with respect to the grammar up to a given depth and a given size. 
The exploration is done using the given priority function for derivations, and the expand function for discovered nodes.
Concrete iterators may overload the following methods:
- priority_function
- derivation_heuristic
- hole_heuristic
"""
abstract type TopDownIterator <: ProgramIterator end

"""
    priority_function(::TopDownIterator, g::AbstractGrammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}}, isrequeued::Bool)

Assigns a priority value to a `tree` that needs to be considered later in the search. Trees with the lowest priority value are considered first.

- ``: The first argument is a dispatch argument and is only used to dispatch to the correct priority function
- `g`: The grammar used for enumeration
- `tree`: The tree that is about to be stored in the priority queue
- `parent_value`: The priority value of the parent [`SolverState`](@ref)
- `isrequeued`: The same tree shape will be requeued. The next time this tree shape is considered, the `UniformSolver` will produce the next complete program deriving from this shape.
"""
function priority_function(
    ::TopDownIterator, 
    g::AbstractGrammar, 
    tree::AbstractRuleNode, 
    parent_value::Union{Real, Tuple{Vararg{Real}}},
    isrequeued::Bool
)
    #the default priority function is the bfs priority function
    parent_value + 1;
end

"""
    function derivation_heuristic(::TopDownIterator, indices::Vector{Int})

Returns a sorted sublist of the `indices`, based on which rules are most promising to fill a hole.
By default, this is the identity function.
"""
function derivation_heuristic(::TopDownIterator, indices::Vector{Int})
    return indices;
end

"""
    hole_heuristic(::TopDownIterator, node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason, HoleReference}

Defines a heuristic over variable shaped holes. Returns a [`HoleReference`](@ref) once a hole is found.
"""
function hole_heuristic(::TopDownIterator, node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason, HoleReference}
    return heuristic_leftmost(node, max_depth);
end

Base.@doc """
    @programiterator RandomIterator() <: TopDownIterator

Iterates trees in the grammar in a random order.
""" RandomIterator
@programiterator RandomIterator() <: TopDownIterator

"""
    priority_function(::RandomIterator, g::AbstractGrammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}}, isrequeued::Bool)

Assigns a random priority to each state.
"""
function priority_function(
    ::RandomIterator, 
    ::AbstractGrammar, 
    ::AbstractRuleNode, 
    ::Union{Real, Tuple{Vararg{Real}}},
    ::Bool
)
    Random.rand();
end

"""
    function derivation_heuristic(::RandomIterator, indices::Vector{Int})

Randomly shuffles the rules.
"""
function derivation_heuristic(::RandomIterator, indices::Vector{Int})
    return Random.shuffle!(indices);
end


Base.@doc """
    @programiterator BFSIterator() <: TopDownIterator

Returns a breadth-first iterator given a grammar and a starting symbol. Returns trees in the grammar in increasing order of size. Inherits all stop-criteria from TopDownIterator.
""" BFSIterator
@programiterator BFSIterator() <: TopDownIterator

"""
    priority_function(::BFSIterator, g::AbstractGrammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}}, isrequeued::Bool)

Assigns priority such that the search tree is traversed like in a BFS manner
"""
function priority_function(
    ::BFSIterator, 
    ::AbstractGrammar, 
    ::AbstractRuleNode, 
    parent_value::Union{Real, Tuple{Vararg{Real}}},
    isrequeued::Bool
)
    if isrequeued
        return parent_value;
    end
    return parent_value + 1;
end


Base.@doc """
    @programiterator DFSIterator() <: TopDownIterator

Returns a depth-first search enumerator given a grammar and a starting symbol. Returns trees in the grammar in decreasing order of size. Inherits all stop-criteria from TopDownIterator.
""" DFSIterator
@programiterator DFSIterator() <: TopDownIterator

"""
    priority_function(::DFSIterator, g::AbstractGrammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}}, isrequeued::Bool)

Assigns priority such that the search tree is traversed like in a DFS manner
"""
function priority_function(
    ::DFSIterator, 
    ::AbstractGrammar, 
    ::AbstractRuleNode, 
    parent_value::Union{Real, Tuple{Vararg{Real}}},
    isrequeued::Bool
)
    if isrequeued
        return parent_value;
    end
    return parent_value - 1;
end


Base.@doc """
    @programiterator MLFSIterator() <: TopDownIterator

Iterator that enumerates expressions in the grammar in decreasing order of probability (Only use this iterator with probabilistic grammars). Inherits all stop-criteria from TopDownIterator.
""" MLFSIterator
@programiterator MLFSIterator() <: TopDownIterator

"""
    priority_function(::MLFSIterator, g::AbstractGrammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}}, isrequeued::Bool)

Calculates logit for all possible derivations for a node in a tree and returns them.
"""
function priority_function(
    ::MLFSIterator,
    g::AbstractGrammar, 
    tree::AbstractRuleNode, 
    ::Union{Real, Tuple{Vararg{Real}}},
    isrequeued::Bool
)
    -rulenode_log_probability(tree, g)
end

"""
    @enum ExpandFailureReason limit_reached=1 already_complete=2

Representation of the different reasons why expanding a partial tree failed. 
Currently, there are two possible causes of the expansion failing:

- `limit_reached`: The depth limit or the size limit of the partial tree would 
   be violated by the expansion
- `already_complete`: There is no hole left in the tree, so nothing can be 
   expanded.
"""
@enum ExpandFailureReason limit_reached=1 already_complete=2


"""
    function Base.collect(iter::TopDownIterator)

Return an array of all programs in the TopDownIterator. 
!!! warning
    This requires deepcopying programs from type StateHole to type RuleNode.
    If it is not needed to save all programs, iterate over the iterator manually.
"""
function Base.collect(iter::TopDownIterator)
    @warn "Collecting all programs of a TopDownIterator requires freeze_state"
    programs = Vector{RuleNode}()
    for program ∈ iter
        push!(programs, freeze_state(program))
    end
    return programs
end

"""
    Base.iterate(iter::TopDownIterator)

Describes the iteration for a given [`TopDownIterator`](@ref) over the grammar. The iteration constructs a [`PriorityQueue`](@ref) first and then prunes it propagating the active constraints. Recursively returns the result for the priority queue.
"""
function Base.iterate(iter::TopDownIterator)
    # Priority queue with `SolverState`s (for variable shaped trees) and `UniformIterator`s (for fixed shaped trees)
    pq :: PriorityQueue{Union{SolverState, UniformIterator}, Union{Real, Tuple{Vararg{Real}}}} = PriorityQueue()

    solver = iter.solver

    if isfeasible(solver)
        enqueue!(pq, get_state(solver), priority_function(iter, get_grammar(solver), get_tree(solver), 0, false))
    end
    return _find_next_complete_tree(iter.solver, pq, iter)
end

"""
    Base.iterate(iter::TopDownIterator, pq::DataStructures.PriorityQueue)

Describes the iteration for a given [`TopDownIterator`](@ref) and a [`PriorityQueue`](@ref) over the grammar without enqueueing new items to the priority queue. Recursively returns the result for the priority queue.
"""
function Base.iterate(iter::TopDownIterator, tup::Tuple{Vector{<:AbstractRuleNode}, DataStructures.PriorityQueue})
    track!(iter.solver, "#CompleteTrees (by FixedShapedIterator)")
    # iterating over fixed shaped trees using the FixedShapedIterator
    if !isempty(tup[1])
        return (pop!(tup[1]), tup)
    end

    return _find_next_complete_tree(iter.solver, tup[2], iter)
end


function Base.iterate(iter::TopDownIterator, pq::DataStructures.PriorityQueue)
    track!(iter.solver, "#CompleteTrees (by UniformSolver)")
    return _find_next_complete_tree(iter.solver, pq, iter)
end

"""
    _find_next_complete_tree(solver::Solver, pq::PriorityQueue, iter::TopDownIterator)::Union{Tuple{RuleNode, Tuple{Vector{AbstractRuleNode}, PriorityQueue}}, Nothing}

Takes a priority queue and returns the smallest AST from the grammar it can obtain from the queue or by (repeatedly) expanding trees that are in the queue.
Returns `nothing` if there are no trees left within the depth limit.
"""
function _find_next_complete_tree(
    solver::Solver,
    pq::PriorityQueue,
    iter::TopDownIterator
)
    while length(pq) ≠ 0
        (item, priority_value) = dequeue_pair!(pq)
        if item isa UniformIterator
            #the item is a fixed shaped solver, we should get the next solution and re-enqueue it with a new priority value
            uniform_iterator = item
            solution = next_solution!(uniform_iterator)
            if !isnothing(solution)
                enqueue!(pq, uniform_iterator, priority_function(iter, get_grammar(solver), solution, priority_value, true))
                return (solution, pq)
            end
        elseif item isa SolverState
            #the item is a solver state, we should find a variable shaped hole to branch on
            state = item
            load_state!(solver, state)

            hole_res = hole_heuristic(iter, get_tree(solver), get_max_depth(solver))
            if hole_res ≡ already_complete
                track!(solver, "#FixedShapedTrees")
                if solver.use_uniformsolver
                    uniform_solver = UniformSolver(get_grammar(solver), get_tree(solver), with_statistics=solver.statistics)
                    uniform_iterator = UniformIterator(uniform_solver, iter)
                    solution = next_solution!(uniform_iterator)
                    if !isnothing(solution)
                        enqueue!(pq, uniform_iterator, priority_function(iter, get_grammar(solver), solution, priority_value, true))
                        return (solution, pq)
                    end
                else
                    fixed_shaped_iter = FixedShapedIterator(get_grammar(solver), :StartingSymbolIsIgnored, solver=solver)
                    complete_trees = collect(fixed_shaped_iter)
                    if !isempty(complete_trees)
                        return (pop!(complete_trees), (complete_trees, pq))
                    end
                end
            elseif hole_res ≡ limit_reached
                # The maximum depth is reached
                continue
            elseif hole_res isa HoleReference
                # Variable Shaped Hole was found
                (; hole, path) = hole_res
        
                partitioned_domains = partition(hole, get_grammar(solver))
                number_of_domains = length(partitioned_domains)
                for (i, domain) ∈ enumerate(partitioned_domains)
                    if i < number_of_domains
                        state = save_state!(solver)
                    end
                    @assert isfeasible(solver) "Attempting to expand an infeasible tree: $(get_tree(solver))"
                    remove_all_but!(solver, path, domain)
                    if isfeasible(solver)
                        enqueue!(pq, get_state(solver), priority_function(iter, get_grammar(solver), get_tree(solver), priority_value, false))
                    end
                    if i < number_of_domains
                        load_state!(solver, state)
                    end
                end
            end
        else
            throw("BadArgument: PriorityQueue contains an item of unexpected type '$(typeof(item))'")
        end
    end
    return nothing
end
