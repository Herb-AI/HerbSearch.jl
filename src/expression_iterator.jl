abstract type ExpressionIterator end

Base.IteratorSize(::ExpressionIterator) = Base.SizeUnknown()

Base.eltype(::ExpressionIterator) = RuleNode