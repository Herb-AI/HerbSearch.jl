"""
    abstract type AbstractSearchStrategy

Abstract super-type for all possible search strategies of an [`ProgramIterator`](@ref)
"""
abstract type AbstractSearchStrategy end

"""
    mutable struct ProgramIterator

Generic iterator for all possible search strategies.    
All iterators are expected to have the following fields:

- `strategy::AbstractSearchStrategy`: defines the search strategy of this iterator
- `grammar::ContextSensitiveGrammar`: the grammar to search over
- `start::Symbol`: defines the start symbol from which the search should be started 
- `max_depth::Int`: maximum depth of program trees
- `max_size::Int`: maximum number of [`AbstractRuleNode`](@ref)s of program trees
- `max_time::Int`: maximum time the iterator may take
- `max_enumerations::Int`: maximum number of enumerations
"""
abstract type ProgramIterator end

Base.IteratorSize(::ProgramIterator) = Base.SizeUnknown()

Base.eltype(::ProgramIterator) = RuleNode
