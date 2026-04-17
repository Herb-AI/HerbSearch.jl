function sign_ternary(inputs::Vector{String}, intermediates::Vector{String}, outputs::Vector{String})::Vector{Int8}
    vcat(
        sign_unary(inputs),
        sign_unary(intermediates),
        sign_unary(outputs),
        sign_binary(inputs, outputs),
        sign_binary(intermediates, outputs),
    )
end

function aggregate(values::Vector{Bool})::Int8
    if all(values)
        return 1
    elseif !any(values)
        return -1
    else
        return 0
    end
end

function aggregate(values::Vector{Vector{Bool}})::Vector{Int8} #[aggregate(values[:][i]) for i in 1:length(values)]
    ncols = length(values[1])
    res = []

    for j in 1:ncols
        col = [row[j] for row in values]
        push!(res, aggregate(col))
    end 

    return res
end

function sign_unary(str::String)::Vector{Bool}
    [
        isempty(str),                         # 1. is empty?
        length(str) == 1,                     # 2. is single char?
        length(str) <= 5,                     # 3. is short string?
        str == lowercase(str),                # 4. is lowercase?
        str == uppercase(str),                # 5. is uppercase?
        occursin(" ", str),                   # 6. contains space?
        occursin(",", str),                   # 7. contains comma?
        occursin(".", str),                   # 8. contains period?
        occursin("-", str),                   # 9. contains dash?
        occursin("/", str),                   # 10. contains slash?
        occursin(r"\d", str),                 # 11. contains digits?
        occursin(r"^\d+$", str),              # 12. only digits?
        occursin(r"[A-Za-z]", str),           # 13. contains letters?
        occursin(r"^[A-Za-z]+$", str)         # 14. only letters?
    ]
end

sign_unary(strs::Vector{String})::Vector{Int8} = aggregate([sign_unary(s) for s in strs])

function sign_binary(input_string::String, output_string::String)::Vector{Bool}
    input_lower = lowercase(input_string)
    output_string_lower = lowercase(output_string)

    [
        occursin(input_string, output_string),                 # 1. output contains input?
        startswith(output_string, input_string),               # 2. output starts with input?
        endswith(output_string, input_string),                 # 3. output ends with input?
        occursin(output_string, input_string),                 # 4. input contains output?
        startswith(input_string, output_string),               # 5. input starts with output?
        endswith(input_string, output_string),                 # 6. input ends with output?
        occursin(input_lower, output_string_lower),            # 7. output contains input ignoring case?
        startswith(output_string_lower, input_lower),          # 8. output starts with input ignoring case?
        endswith(output_string_lower, input_lower),            # 9. output ends with input ignoring case?
        occursin(output_string_lower, input_lower),            # 10. input contains output ignoring case?
        startswith(input_lower, output_string_lower),          # 11. input starts with output ignoring case?
        endswith(input_lower, output_string_lower),            # 12. input ends with output ignoring case?
        input_string == output_string,                         # 13. input equals output?
        input_lower == output_string_lower,                    # 14. input equals output ignoring case?
        length(input_string) == length(output_string),         # 15. same length?
        length(input_string) < length(output_string),          # 16. input shorter?
        length(input_string) > length(output_string)           # 17. input longer?
    ]
end

sign_binary(input_strings::Vector{String}, output_strings::Vector{String})::Vector{Int8} = aggregate([sign_binary(i, o) for (i, o) in zip(input_strings, output_strings)])
