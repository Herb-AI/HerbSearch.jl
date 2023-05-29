using Random

HeuristicResult = Tuple{Hole, Vector{Int}}

function heuristic_leftmost(node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason, HeuristicResult}
    function leftmost(node::RuleNode, max_depth::Int, path::Vector{Int})::Union{ExpandFailureReason, HeuristicResult}
        if max_depth == 0 return limit_reached end

        for (i, child) in enumerate(node.children)
            new_path = push!(copy(path), i)
            hole_res = leftmost(child, max_depth-1, new_path)
            if (hole_res == limit_reached) || (hole_res isa HeuristicResult)
                return hole_res
            end
        end
    
        return already_complete
    end
    
    function leftmost(hole::Hole, max_depth::Int, path::Vector{Int})::Union{ExpandFailureReason, HeuristicResult}
        if max_depth == 0 return limit_reached end
        return (hole, path)
    end

    return leftmost(node, max_depth, Vector{Int}())
end


function heuristic_rightmost(node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason, HeuristicResult}
    function rightmost(node::RuleNode, max_depth::Int, path::Vector{Int})::Union{ExpandFailureReason, HeuristicResult}
        if max_depth == 0 return limit_reached end

        for (i, child) in Iterators.reverse(enumerate(node.children))
            new_path = push!(copy(path), i)
            hole_res = rightmost(child, max_depth-1, new_path)
            if (hole_res == limit_reached) || (hole_res isa HeuristicResult)
                return hole_res
            end
        end
    
        return already_complete
    end
    
    function rightmost(hole::Hole, max_depth::Int, path::Vector{Int})::Union{ExpandFailureReason, HeuristicResult}
        if max_depth == 0 return limit_reached end
        return (hole, path)
    end

    return rightmost(node, max_depth, Vector{Int}())
end


function heuristic_random(node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason, HeuristicResult}
    function random(node::RuleNode, max_depth::Int, path::Vector{Int})::Union{ExpandFailureReason, HeuristicResult}
        if max_depth == 0 return limit_reached end

        for (i, child) in shuffle(collect(enumerate(node.children)))
            new_path = push!(copy(path), i)
            hole_res = random(child, max_depth-1, new_path)
            if (hole_res == limit_reached) || (hole_res isa HeuristicResult)
                return hole_res
            end
        end
    
        return already_complete
    end
    
    function random(hole::Hole, max_depth::Int, path::Vector{Int})::Union{ExpandFailureReason, HeuristicResult}
        if max_depth == 0 return limit_reached end
        return (hole, path)
    end

    return random(node, max_depth, Vector{Int}())
end


function heuristic_smallest_domain(node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason, HeuristicResult}
    function smallest_domain(node::RuleNode, max_depth::Int, path::Vector{Int})::Union{ExpandFailureReason, HeuristicResult}
        if max_depth == 0 return limit_reached end

        smallest_size::Int = typemax(Int)
        smallest_result::Union{Nothing, HeuristicResult} = nothing

        for (i, child) in enumerate(node.children)
            new_path = push!(copy(path), i)
            hole_res = smallest_domain(child, max_depth-1, new_path)

            if hole_res == limit_reached
                return hole_res
            end

            if hole_res isa HeuristicResult
                hole, _ = hole_res
                domain_size = count(hole.domain)
                if domain_size < smallest_size
                    smallest_size = domain_size
                    smallest_result = hole_res
                end
            end
        end
    
        if isnothing(smallest_result) return already_complete end
        return smallest_result
    end
    
    function smallest_domain(hole::Hole, max_depth::Int, path::Vector{Int})::Union{ExpandFailureReason, HeuristicResult}
        if max_depth == 0 return limit_reached end
        return (hole, path)
    end

    return smallest_domain(node, max_depth, Vector{Int}())
end
