"""
The propose functions return the fully constructed proposed programs given a path to a location to fill in.
"""

"""
    random_fill_propose(solver::Solver, path::Vector{Int}, nr_random=5)

Returns a list with only one proposed, completely random, subprogram.
# Arguments
- `solver::solver`: solver
- `path::Vector{Int}`: path to the location to be filled.
- `nr_random`=1 : the number of random subprograms to be generated.
"""
function random_fill_propose(solver::Solver, path::Vector{Int}, nr_random=1)
    return Iterators.take(RandomSearchIterator(solver, path), nr_random)
end 

"""
    enumerate_neighbours_propose(enumeration_depth::Int)

Takes a program with a hole. Returns a `BFSIterator` jumpstarted with that program. 
"""
function enumerate_neighbours_propose(enumeration_depth::Int=5)
    return (solver::Solver, path::Vector{Int}) -> begin
        return BFSIterator(solver)
    end
end


"""
    propose_shape(iter::StochasticSearchIterator, grammar::AbstractGrammar, hole_path::Vector{Int}; max_depth=5)

Samples a random shape/uniform tree for the hole at `hole_path` to propose programs from. 
Returns an iterator over the uniform tree.
"""
function propose_shape(iter::StochasticSearchIterator, grammar::AbstractGrammar, hole_path::Vector{Int}; shape_depth=3)
        # Get AbstractRuleNode from path and check whether its a hole
        solver = iter.solver
        current_program = get_tree(solver)

        node = get_node_at_location(current_program, hole_path)

        # Ugly, see https://github.com/Herb-AI/HerbCore.jl/issues/50
        if node isa AbstractHole
                type = grammar.types[findfirst(node.domain)]
        else
                type = grammar.types[get_rule(node)]
        end

        # Sample shape from type
        max_depth = get_max_depth(iter.solver) - length(hole_path)
        @assert max_depth > 0
        shape = rand(UniformHole, grammar, type, min(shape_depth, max_depth))

        # Substitute shape into the hole
        substitute!(solver, hole_path, shape)

        # Create a uniform solver over the new shape
        uniform_solver = UniformSolver(grammar, get_tree(solver), with_statistics=solver.statistics)
        uniform_iterator = UniformIterator(uniform_solver, iter)

        return uniform_iterator
end
