const DEFAULT_CAPACITY = 32768
const LOAD_FACTOR = 0.8

mutable struct LongHashMap
    keys::Vector{UInt64}
    occupied::Vector{Bool}
    size::Int
end

function init_long_hash_map()
    keys = Vector{UInt64}(undef, DEFAULT_CAPACITY)
    occupied = Vector{Bool}(undef, DEFAULT_CAPACITY)
    fill!(occupied, false)
    LongHashMap(keys, occupied, 0)
end

function lhm_hash(key::UInt64, capacity::Int64)
    return (key >>> 32) % capacity
end

function lhm_resize!(map::LongHashMap)
    new_capacity = length(map.keys) * 2
    new_keys = Vector{UInt64}(undef, new_capacity)
    new_occupied = Vector{Bool}(undef, new_capacity)
    fill!(new_occupied, false)
    
    for i in 1:length(map.keys)
        if map.occupied[i]
            index = lhm_hash(map.keys[i], new_capacity)
            while new_occupied[index + 1]
                index = (index + 1) % new_capacity
            end
            new_keys[index + 1] = map.keys[i]
            new_occupied[index + 1] = true
        end
    end

    map.keys = new_keys
    map.occupied = new_occupied
end

function lhm_put!(map::LongHashMap, key::UInt64)
    if (map.size / length(map.keys)) >= LOAD_FACTOR
        lhm_resize!(map)
    end
    index = lhm_hash(key, length(map.keys))
    while map.occupied[index + 1]
        if map.keys[index + 1] == key
            return
        end
        index = (index + 1) % length(map.keys)
    end
    map.keys[index + 1] = key
    map.occupied[index + 1] = true
    map.size += 1
end

function lhm_contains(map::LongHashMap, key::UInt64)
    index = lhm_hash(key, length(map.keys))
    while map.occupied[index + 1]
        if map.keys[index + 1] == key
            return true
        end
        index = (index + 1) % length(map.keys)
    end
    return false
end