"""
Returns the temperature unchanged.
# Arguments
- `current_temperature::Float`: the current temperature of the search.
"""
function const_temperature(current_temperature)
    return current_temperature
end


"""
Returns a function that produces a temperature decreased by `percentage`%.
"""
function decreasing_temperature(percentage)
    return current_temperature -> percentage * current_temperature
end