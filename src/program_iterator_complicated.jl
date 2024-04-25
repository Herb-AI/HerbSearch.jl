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

function generate_iterator(mod::Module, ex::Expr, mut::Bool=true)
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
        # create field names
        field_names = map(extract_name_from_argument, extrafields)

        # throw an error if user used one of the reserved arg names 
        RESERVERD_ARG_NAMES = [:solver,:start_symbol,:initial_node,:grammar,:max_depth,:max_size]
        for field_name ∈ field_names
            println(field_name)
            if field_name ∈ RESERVERD_ARG_NAMES
                throw(ArgumentError(
                    "When using the @programiterator macro you are not allowed to use any of the $RESERVERD_ARG_NAMES field names.
                     This is because there would be conflicting names in the function signature. 
                     However, '$field_name' was found as an argument name. 
                     Please change the name of the field argument to not collide with the reserved argument names above.
                    "))
            end
        end

        # TODO: Refactor using expressions 
        # TODO: Allow kwargs in the solver constructor too (but only if there any kwargs)

        basekwargs = Vector{Expr}()

        head = Expr(:(<:), name, isnothing(super) ? :(HerbSearch.ProgramIterator) : :($mod.$super))
        fields = Base.remove_linenums!(quote
            solver::Solver
        end)

        map!(ex -> processkwarg!(basekwargs, ex), extrafields, extrafields)        
        append!(fields.args, extrafields)
        
        constrfields = copy(fields)
        map!(esc, constrfields.args, constrfields.args)
        struct_decl = Expr(:struct, mut, esc(head), constrfields)

        keyword_fields = map(kwex -> kwex.args[1], basekwargs)
        required_fields = filter(field -> field ∉ keyword_fields && is_field_decl(field), fields.args)

        function createConstructor(required_fields_input, field_args_function_body, expr_before::Union{Nothing,Expr} = nothing)
            argument_names = (esc ∘ extractname).(filter(is_field_decl, field_args_function_body))
            @show argument_names
            if !isnothing(expr_before)
                argument_names = vcat([esc(expr_before)], argument_names)
            end
            Expr(:(=), 
                Expr(:call, esc(name), Expr(:parameters, esc.(basekwargs)...), esc.(required_fields_input)...), 
                Expr(:call, esc(name), argument_names... )
            )
        end
        solver_constructor = createConstructor(required_fields, fields.args)


        @show basekwargs
        # for constructors that do not use the solver we have to add max_size and max_depth as kwargs
        # very ugly but this adds max_size and max_size as kwargs with default of maxint
        push!(basekwargs, :($(Expr(:kw, :(max_depth::Int), Expr(:call,:typemax,:Int)))))
        push!(basekwargs, :($(Expr(:kw, :(max_size::Int), Expr(:call,:typemax,:Int)))))

        @show fields.args
        @show required_fields
        

        input_fields_without_solver = filter(field -> field != :(solver::Solver), required_fields)
        output_fields_without_solver = filter(field -> field != :(solver::Solver), fields.args)

        # concatenate gramamr+symbol with the rest of the fields that do not have the solver
        input_with_grammar_rulenode =  vcat([:(grammar ), :(start_symbol :: Symbol)] , input_fields_without_solver)
        create_solver_expr = :(GenericSolver(grammar, start_symbol, max_size = max_size, max_depth = max_depth))
        # create grammar,sym -> Solver(grammar,sym)
        constructor_grammar_sym = createConstructor(input_with_grammar_rulenode, output_fields_without_solver, create_solver_expr)
        
        input_with_grammar_rulenode =  vcat([:(grammar), :(initial_node :: RuleNode)] , input_fields_without_solver)
        create_solver_expr = :(GenericSolver(grammar, initial_node, max_size = max_size, max_depth = max_depth))
        # create grammar,rulenode -> Solver(grammar,rulenode)
        constructor_grammar_rulenode = createConstructor(input_with_grammar_rulenode, output_fields_without_solver, create_solver_expr)

        struct_decl, constructor_grammar_sym #, constructor_grammar_rulenode
    end
    _ => throw(ArgumentError("invalid declaration structure for the iterator"))
end

extractname(ex) = @match ex begin
    Expr(:(::), name, type) => name
    name::Symbol            => name
    _ => throw(ArgumentError("unexpected field: $ex"))
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
