using DataStructures


# express graph as an adjencecy list
# input: n, m; each edge, u, v, weight
# output: graph as an adjencecy list
# """
function graph_as_adj_list_dict(n::Int, m::Int, edges::Vector{Tuple{Int,Int,Int}})
    graph = Dict{Int,Vector{Tuple{Int,Int}}}()
    for i ∈ 1:n
        graph[i] = []
    end
    for edge ∈ edges
        u, v, w = edge
        push!(graph[u], (v, w))
    end
    return graph
end


a = graph_as_adj_list_dict(5, 5, [(1, 2, 3), (1, 3, 4), (2, 4, 5), (3, 4, 6), (4, 5, 7)])
# println(a)
# Dict{Int64,Array{Tuple{Int64,Int64},1}}(4 => [(5, 7)],2 => [(4, 5)],3 => [(4, 6)],5 => Tuple{Int64,Int64}[],1 => [(2, 3), (3, 4)])



function graph_as_adj_list_array(n::Int, edges::Vector{Tuple{Int,Int,Int}})::Vector{Vector{Tuple{Int,Int}}}
    graph = Vector{Vector{Tuple{Int,Int}}}(undef, n)

    for i ∈ 1:n
        graph[i] = []
    end

    for edge ∈ edges
        u, v, w = edge
        push!(graph[u], (v, w))
    end
    return graph
end

a = graph_as_adj_list_array(5, [(1, 2, 3), (1, 3, 4), (2, 4, 5), (3, 4, 6), (4, 5, 7)])
# println(a)


function explore_dfs(graph::Vector{Vector{Tuple{Int,Int}}})::Nothing
    n = length(graph)
    stack = Vector{Int}()
    visited = falses(n)
    push!(stack, 1)
    visited[1] = true
	
    while !isempty(stack)
        curr = pop!(stack)
        println(curr)
        for neigh ∈ graph[curr]
            v, _ = neigh
            if !visited[v]
                push!(stack, v)
                visited[v] = true
            end
        end
    end
	
end

# explore_dfs(a)

println("===========")

function explore_bfs(graph::Vector{Vector{Tuple{Int,Int}}})::Nothing
	n = length(graph)
	queue = Queue{Int}()
	visited = falses(n)
	enqueue!(queue, 1)
	visited[1] = true

	while !isempty(queue)
		curr = dequeue!(queue)
		println(curr)
		for neigh ∈ graph[curr]
			v, w = neigh
			if !visited[v]
				enqueue!(queue, v)
				visited[v] = true
			end
		end
	end

end

# explore_bfs(a)

function _test_pq()::Nothing
	pq = PriorityQueue{Int, Int}()
	pq[1] = 1000
	pq[2] = 3
	push!(pq, Pair(3, 1))
	println(dequeue_pair!(pq))
	println(dequeue!(pq))
end

_test_pq()


function _wont_catch_me(graph::Vector{Vector{Tuple{Int, Int}}})::Vector{Int}
	pq = PriorityQueue{Int, Int}()
	n = length(graph)
	dist = fill(Inf, n)
	dist[1] = 0
	push!(pq, Pair(1, 0)) # sortirame po vtoro, spoko.

	while (!isempty(pq))
		x, _ = dequeue_pair!(pq)
		for neigh ∈ graph[x]
			y, w = neigh
			if dist[y] > dist[x] + w
				dist[y] = dist[x] + w
				push!(pq, Pair(y, dist[y]))
			end
		end
	end

	return dist
end

# distances::Vector{Int} = _wont_catch_me(a)
# println(distances)


function _test_copy_dictionary()::Nothing
	d = Dict(1 => 2, 3 => 4)
	d2 = Dict(d)
	d[1] = 100
	println(d)
	println(d2)
end

_test_copy_dictionary()
