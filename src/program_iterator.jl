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
    @programiterator

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
is a subtype of `ProgramIterator` which otherwise throws an ArgumentError.
If no supertype is given, the new iterator extends `ProgramIterator` directly.
Each <argᵢ> may be (almost) any expression valid in a struct declaration, and they must be comma separated.
One known exception is that an inner constructor must always be given using the extended `function <name>(...) ... end` syntax.
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
            Expr(:block, check, processdecl(mod, mut, decl, super)...)
        end
        decl => Expr(:block, processdecl(mod, mut, decl)...)
    end
end

processdecl(mod::Module, mut::Bool, decl::Expr, super=nothing) = @match decl begin
    Expr(:call, name::Symbol, extrafields...) => begin
        kwargs = [
            Expr(:kw, :(max_depth::Int), typemax(Int)), 
            Expr(:kw, :(max_size::Int), typemax(Int)), 
            Expr(:kw, :(max_time::Int), typemax(Int)), 
            Expr(:kw, :(max_enumerations::Int), typemax(Int))
        ]

        head = Expr(:(<:), name, isnothing(super) ? :(HerbSearch.ProgramIterator) : :($mod.$super))
        fields = Base.remove_linenums!(quote
            grammar::ContextSensitiveGrammar
            sym::Symbol
            max_depth::Int
            max_size::Int
            max_time::Int
            max_enumerations::Int
        end)

        map!(ex -> processkwarg!(kwargs, ex), extrafields, extrafields)        
        append!(fields.args, extrafields)
        
        constrfields = copy(fields)
        map!(esc, constrfields.args, constrfields.args)
        struct_decl = Expr(:struct, mut, esc(head), constrfields)

        keyword_fields = map(kwex -> kwex.args[1], kwargs)
        required_fields = filter(field -> field ∉ keyword_fields && is_field_decl(field), fields.args)

        constructor = Expr(:(=), 
            Expr(:call, esc(name), Expr(:parameters, esc.(kwargs)...), esc.(required_fields)...), 
            Expr(:call, esc(name), (esc ∘ extractname).(filter(is_field_decl, fields.args))...)
        )

        struct_decl, constructor
    end
    _ => throw(ArgumentError("invalid declaration structure for the iterator"))
end

"""
    extractname(ex)

Extracts the name of a field declaration, otherwise throws an `ArgumentError`.
A field declaration is of the form `<name>[::<type>]`
"""
extractname(ex) = @match ex begin
    Expr(:(::), name, type) => name
    name::Symbol            => name
    _ => throw(ArgumentError("unexpected field: $ex"))
end


"""
    is_field_decl(ex)

Check if `extractname(ex)` returns a name.
"""
is_field_decl(ex) = try extractname(ex)
    true 
catch e 
    if e == ArgumentError("unexpected field: $ex")
        false
    else throw(e) end 
end


"""
    processkwarg!(keywords::Vector{Expr}, ex::Union{Expr, Symbol})

Checks if `ex` has a default value specified, if so it returns only the field declaration, 
and pushes `ex` to `keywords`. Otherwise it returns `ex`
"""
processkwarg!(keywords::Vector{Expr}, ex::Union{Expr, Symbol}) = @match ex begin
    Expr(:kw, field_decl, ::Any) => begin
        push!(keywords, ex)
        field_decl
    end
    _ => ex
end