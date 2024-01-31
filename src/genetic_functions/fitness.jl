"""
    default_fitness(program, results)

Defines the default fitness function taking the program and its results. Results are a vector of tuples, where each tuple is in the form `Tuple{expected_output, actual_output}`. As we are looking for individuals with the highest fitness function, the error is inverted. 
"""
function default_fitness(program, results)
    casted_vec = Tuple{<:Number, <:Number}[]

    for (val_1, val_2) in results
        if val_1 isa Number && val_2 isa Number
            push!(casted_vec, (val_1, val_2))
        else
            throw(ArgumentError("Cannot cast Tuple{Number, Any} to Tuple{Number, Number}: non-numeric value found"))
        end
    end

    1 / mean_squared_error(casted_vec)
end
