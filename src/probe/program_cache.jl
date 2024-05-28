"""
    struct ProgramCache 

Stores the evaluation cost and the program in a structure.
This 
"""
mutable struct ProgramCache
    program::RuleNode
    correct_examples::Vector{Int}
    cost::Int
end
function Base.:(==)(a::ProgramCache, b::ProgramCache)
    return a.program == b.program
end

Base.hash(a::ProgramCache) = hash(a.program)

mutable struct ProgramCacheTrace
    program::RuleNode
    cost::Int
    reward::Float64
end

function Base.:(==)(a::ProgramCacheTrace, b::ProgramCacheTrace)
    return a.program == b.program
end

Base.hash(a::ProgramCacheTrace) = hash(a.program)
