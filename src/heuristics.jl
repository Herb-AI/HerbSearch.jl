

function heuristic_leftmost(node::AbstractRuleNode)::Vector{Int}
    function leftmost(node::RuleNode, path::Vector{Int})::Union{Nothing, Vector{Int}}
        for (i, child) in enumerate(node.children)
            maybe_res = leftmost(child, push!(copy(path), i))
            if !isnothing(maybe_res)
                return maybe_res
            end
        end
    
        return nothing
    end
    
    leftmost(::Hole, path::Vector{Int})::Union{Nothing,Vector{Int}} = path

    return leftmost(node, [])
end


function heuristic_rightmost(node::AbstractRuleNode)::Vector{Int}
    function rightmost(node::RuleNode, path::Vector{Int})::Union{Nothing, Vector{Int}}
        for (i, child) in Iterators.reverse(enumerate(node.children))
            maybe_res = rightmost(child, push!(copy(path), i))
            if !isnothing(maybe_res)
                return maybe_res
            end
        end
    
        return nothing
    end
    
    rightmost(::Hole, path::Vector{Int})::Union{Nothing,Vector{Int}} = path

    return rightmost(node, [])
end


function heuristic_random(node::AbstractRuleNode)::Vector{Int}
    function random(node::RuleNode, path::Vector{Int})::Union{Nothing, Vector{Int}}
        for (i, child) in shuffle(collect(enumerate(node.children)))
            maybe_res = random(child, push!(copy(path), i))
            if !isnothing(maybe_res)
                return maybe_res
            end
        end
    
        return nothing
    end
    
    random(::Hole, path::Vector{Int})::Union{Nothing,Vector{Int}} = path

    return random(node, [])
end


function heuristic_smallest_domain(node::AbstractRuleNode)::Vector{Int}
    function smallest_domain(node::RuleNode, path::Vector{Int})::Union{Nothing, Tuple{Int, Vector{Int}}}
        if node.children == []
            return nothing
        end
        
        smallest_size::Int = typemax(Int)
        smallest_path::Vector{Int} = []

        for (i, child) in shuffle(collect(enumerate(node.children)))
            maybe_res = smallest_domain(child, push!(copy(path), i))
            if !isnothing(maybe_res)
                (size, path) = maybe_res
                if size < smallest_size
                    smallest_size = size
                    smallest_path = path
                end
            end
        end

        return (smallest_size, smallest_path)
    end
    
    smallest_domain(hole::Hole, path::Vector{Int})::Union{Nothing, Tuple{Int, Vector{Int}}} = (count(hole.domain), path)

    (size, path) = smallest_domain(node, [])

    return path
end
