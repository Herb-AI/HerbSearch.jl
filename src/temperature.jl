"""
Returns the temperature unchanged.
# Arguments
- `current_temperature::Float`: the current temperature of the search.
"""
function const_temperature(current_temperature)
    return current_temperature
end

"""
Returns the temperature decreased by 1%.
# Arguments
- `current_temperature::Float`: the current temperature of the search.
"""
function decreasing_temperature(current_temperature)
    return 0.99 * current_temperature
end