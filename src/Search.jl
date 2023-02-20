module Search

using DataStructures
using ..Grammars
using ..Data
using ..Evaluation

include("utils.jl")
include("iterators.jl")
include("priority_enumerator.jl")
include("search_procedure.jl")

export 
  count_expressions,
  ExpressionIterator,
  ContextFreeEnumerator,
  ContextFreeBFSEnumerator,
  
  search,

  bfs_expand_heuristic,
  bfs_priority_function,
  get_bfs_enumerator,

  dfs_expand_heuristic,
  dfs_priority_function,
  get_dfs_enumerator
end
