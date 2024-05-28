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

Base.eltype(::ProgramIterator) = Union{RuleNode,StateHole}


"""
    Base.length(iter::ProgramIterator)    

Counts and returns the number of possible programs without storing all the programs.
!!! warning: modifies and exhausts the iterator
"""
function Base.length(iter::ProgramIterator)
    l = 0
    for _ ∈ iter
        l += 1
    end
    return l
end


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
        kwargs_fields = map(esc, filter(is_kwdef, extrafields))
        notkwargs     = map(esc, filter(!is_kwdef, extrafields))

        # create field names
        field_names = map(extract_name_from_argument, extrafields)

        # throw an error if user used one of the reserved arg names 
        RESERVERD_ARG_NAMES = [:solver,:start_symbol,:initial_node,:grammar,:max_depth,:max_size]
        for field_name ∈ field_names
            if field_name ∈ RESERVERD_ARG_NAMES
                throw(ArgumentError(
                    "When using the @programiterator macro you are not allowed to use any of the $RESERVERD_ARG_NAMES field names.
                     This is because there would be conflicting names in the function signature. 
                     However, '$field_name' was found as an argument name. 
                     Please change the name of the field argument to not collide with the reserved argument names above.
                    "))
            end
        end

        field_names = map(esc, field_names)
        escaped_name = esc(name) # this is the name of the struct

        # keyword arguments come after the normal arguments (notkwargs)
        all_constructors = Base.remove_linenums!(
            :(
              begin 
                # solver main constructor
                function $(escaped_name)( $(notkwargs...) ; solver::Solver, max_size = nothing, max_depth = nothing, $(kwargs_fields...) )
                    if !isnothing(max_size) solver.max_size = max_size end
                    if !isnothing(max_depth) solver.max_depth = max_depth end
                    return $(escaped_name)(solver, $(field_names...))
                end
                # solver with grammar and start symbol
                function $(escaped_name)(grammar::AbstractGrammar, start_symbol::Symbol, $(notkwargs...) ; 
                                        max_size = typemax(Int), max_depth = typemax(Int), $(kwargs_fields...) )
                    return $(escaped_name)(GenericSolver(grammar, start_symbol, max_size = max_size, max_depth = max_depth), $(field_names...))
                end

                # solver with grammar and initial rulenode to start with
                function $(escaped_name)(grammar::AbstractGrammar, initial_node::AbstractRuleNode, $(notkwargs...) ;
                                        max_size = typemax(Int), max_depth = typemax(Int), $(kwargs_fields...) )
                    return $(escaped_name)(GenericSolver(grammar, initial_node, max_size = max_size, max_depth = max_depth), $(field_names...))
                end
              end
            )
        )

        # create the struct declaration
        head = Expr(:(<:), name, isnothing(super) ? :(HerbSearch.ProgramIterator) : :($mod.$super))
        fields = Base.remove_linenums!(quote
            solver::Solver
        end)

        kwargs = Vector{Expr}()
        map!(ex -> processkwarg!(kwargs, ex), extrafields, extrafields)
        append!(fields.args, extrafields)

        constrfields = copy(fields)
        map!(esc, constrfields.args, constrfields.args)
        struct_decl = Expr(:struct, mut, esc(head), constrfields)

        # return the expression for the struct declaration and for the constructors
        struct_decl, all_constructors
    end
    _ => throw(ArgumentError("invalid declaration structure for the iterator"))
end


"""
    extract_name_from_argument(ex)

Extracts the name of a field declaration, otherwise throws an `ArgumentError`.
A field declaration is either a simple field name with possible a type attached to it or a keyword argument.

## Example
x::Int     -> x 
hello      -> hello 
x = 4      -> x 
x::Int = 3 -> x
"""
extract_name_from_argument(ex) = 
  @match ex begin 
    Expr(:(::), name, type) => name
    name::Symbol            => name
    Expr(:kw, Expr(:(::), name, type), ::Any) =>  name 
    Expr(:kw, name::Symbol, ::Any) =>  name 
    _ => throw(ArgumentError("unexpected field: $ex"))
  end

""" 
    is_kwdeg(ex)

Checks if a field declaration is a keyword argument or not. 
This is called when filtering if the user arguments to the program iteartor are keyword arguments or not.
"""
is_kwdef(ex) = 
  @match ex begin 
    Expr(:kw, name, type) =>  true
    _ =>  false
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
