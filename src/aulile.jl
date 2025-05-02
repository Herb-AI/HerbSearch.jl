function aulile(
    problem::Problem{<:AbstractVector{<:IOExample}}, 
    iter::ProgramIterator,
    aux::Function,
    max_iterations=typemax(Int))::Union{Tuple{RuleNode, SynthResult}, Nothing}

    for example ∈ problem.spec
        println("Distance between input and output: $(aux(example, example.in[:x]))")
    end

    return nothing

    # for _ in 1:max_iterations
    #     result = synth(problem, iter)
    #     if result isa Nothing
    #         return nothing
    #     else 
    #         program, synth_result = result
    #         if synth_result isa optimal_program
    #             return program
    #         else 
    #             println("Found a suboptimal program")
    #         end
    #     end
    # end
end