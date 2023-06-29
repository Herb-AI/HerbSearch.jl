ContextFreePriorityEnumerator(
    grammar::ContextFreeGrammar, 
    max_depth::Int,
    max_size::Int, 
    priority_function::Function, 
    expand_function::Function,
    sym::Symbol
) = ContextSensitivePriorityEnumerator(
    cfg2csg(grammar),
    max_depth,
    max_size,
    priority_function,
    expand_function, 
    sym
)