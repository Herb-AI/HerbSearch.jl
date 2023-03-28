function const_temperature(previous_temperature)
    return previous_temperature
end

function decreasing_temperature(previous_temperature)
    return 0.99 * previous_temperature
end