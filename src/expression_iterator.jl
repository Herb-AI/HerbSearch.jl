"""
    abstract type ExpressionIterator

Abstract super-type for all possible enumerators.
"""
abstract type ExpressionIterator end

Base.IteratorSize(::ExpressionIterator) = Base.SizeUnknown()

Base.eltype(::ExpressionIterator) = RuleNode
