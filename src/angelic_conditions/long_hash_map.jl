const DEFAULT_CAPACITY = 32768
const LOAD_FACTOR = 0.8

"""
An implementation of bare-bones hashmap that only contains the hash keys, i.e. it does not store the elements, only whether they have been seen/added before.
This is used to keep track of programs that have been generated before, so that they are not generated again, but also does not store them to save on space.

A bloom filter would usually be used for this purpose, but we did not want to introduce other dependencies, and a from-scratch implementation is not trivial.

The "hashmap" only stores the hashes of visited programs, and uses linear probing for collision resolution.

"""
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

# Resizes if the load factor is exceeded
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

# Adding keys to the hashmap
function lhm_put!(map::LongHashMap, key::UInt64)
    # Resize if load factor is exceeded
    if (map.size / length(map.keys)) >= LOAD_FACTOR
        lhm_resize!(map)
    end
    index = lhm_hash(key, length(map.keys))
    # Collision - linear probing
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

# Checking if it has been seen before
function lhm_contains(map::LongHashMap, key::UInt64)
    index = lhm_hash(key, length(map.keys))
    # Collision - linear probing
    while map.occupied[index + 1]
        if map.keys[index + 1] == key
            return true
        end
        index = (index + 1) % length(map.keys)
    end
    return false
end