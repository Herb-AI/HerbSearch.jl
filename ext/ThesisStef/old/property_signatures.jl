function property_signature(
    input_states::Vector{HerbBenchmarks.String_transformations_2020.StringState}, 
    output_states::Vector{HerbBenchmarks.String_transformations_2020.StringState}
)
    Float32.(mean([property_signature(i, o) for (i, o) in zip(input_states, output_states)]))
end

function property_signature(input_state, output_state)
    vcat(
        individual_properties(input_state),               # 11 properties of input
        individual_properties(output_state),              # 11 properties of output
        io_string_properties(input_state, output_state)   # 17 input–output properties
    )
end

function individual_properties_boolean(str::AbstractString)
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

function individual_properties(state)
    str = state.str
    l = length(str)

    if l == 0
        l = 0.0000000001
    end

    [
        l,
        isnothing(state.pointer) ? 0 : state.pointer / l,
        count(islowercase, str) / l,
        count(isuppercase, str) / l,
        count(==(' '), str) / l,
        count(==(','), str) / l,
        count(==('.'), str) / l,
        count(==('-'), str) / l,
        count(==('/'), str) / l,
        count(isdigit, str) / l,
        count(isletter, str) / l,
    ]
end

function io_string_properties(input_state, output_state)
    input_string = input_state.str
    output_string = output_state.str
    input_lower = lowercase(input_string)
    output_string_lower = lowercase(output_string)
    
    result = [
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

    [r ? 1 : -1 for r in result]
end

property_signature_size = length(property_signature(
    HerbBenchmarks.String_transformations_2020.StringState("", nothing),
    HerbBenchmarks.String_transformations_2020.StringState("", nothing)
))