"""
    abstract type ProgramIterator

Generic iterator for all possible search strategies.    
All iterators are expected to have the following fields:

- `grammar::ContextSensitiveGrammar`: the grammar to search over
- `sym::Symbol`: defines the start symbol from which the search should be started 
- `max_depth::Int`: maximum depth of program trees
- `max_size::Int`: maximum number of [`AbstractRuleNode`](@ref)s of program trees
- `max_time::Int`: maximum time the iterator may take
- `max_enumerations::Int`: maximum number of enumerations
"""
abstract type ProgramIterator end

Base.IteratorSize(::ProgramIterator) = Base.SizeUnknown()

Base.eltype(::ProgramIterator) = RuleNode

"""
Canonical way of creating a program iterator.
The macro automatically declares the expected fields listed in the `ProgramIterator` documentation.
Syntax accepted by the macro is as follows (anything enclosed in square brackets is optional):
    ```
    @programiterator [mutable] <IteratorName>(
        <arg₁>,
        ...,
        <argₙ>
    ) [<: <SupertypeIterator>]
    ```
Note that the macro emits an assertion that the `SupertypeIterator` 
extends `ProgramIterator` which otherwise throws an ArgumentError.
If no supertype is given, the new iterator extends `ProgramIterator` directly.
Each <argᵢ> may be any expression valid in a struct declaration, and they must be comma separated.
The `mutable` keyword determines whether the declared struct is mutable.
"""
macro programiterator(mut, ex)
    if mut == :mutable
        generate_iterator(__module__, ex, true)
    else
        throw(ArgumentError("$mut is not a valid argument to @programiterator"))
    end
end

macro programiterator(ex)
    generate_iterator(__module__, ex)
end

function generate_iterator(mod::Module, ex::Expr, mut::Bool=false)
    Base.remove_linenums!(ex)

    @match ex begin
        Expr(:(<:), decl::Expr, super) => begin            
            # a check that `super` is a subtype of `ProgramIterator`
            check = :(eval($mod.$super) <: HerbSearch.ProgramIterator || 
                throw(ArgumentError("attempting to inherit a non-ProgramIterator")))
            
            # process the decl 
            Expr(:block, check, processdecl(mod, mut, decl, super))
        end
        decl => processdecl(mod, mut, decl)
    end
end

processdecl(mod::Module, mut::Bool, decl::Expr, super=nothing) = @match decl begin
    Expr(:call, name::Symbol, extrafields...) => begin
        head = Expr(:(<:), name, isnothing(super) ? :(HerbSearch.ProgramIterator) : :($mod.$super))
        
        fields = quote
            grammar::ContextSensitiveGrammar
            sym::Symbol
            max_depth::Int
            max_size::Int
            max_time::Int
            max_enumerations::Int
        end

        append!(fields.args, extrafields)
        
        Expr(:struct, mut, head, fields)
    end
    _ => throw(ArgumentError("invalid declaration structure for the iterator"))
end