function aulile(problem::Problem, g::AbstractGrammar,
    aux::Function, iter::ProgramIterator, max_iterations::Int)::Union{AbstractRuleNode, Nothing}
    for _ in 1:max_iterations
        result = synth(problem, iter, max_time=1000000, max_enumerations=1000000)
        if result isa Nothing
            return nothing
        else 
            p, solved = result
            print(p)
        end
    end
end