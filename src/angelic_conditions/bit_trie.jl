"""
An implementation of a bare-bones trie data structure
https://en.wikipedia.org/wiki/Trie

This trie does not store values associated to the nodes, and the paths are built using bitstrings instead of regular strings.

The trie is used to store code paths that have been traversed, and check if a given path is a prefix of any of the stored paths.

"""
@kwdef mutable struct BitTrieNode
    left::Union{BitTrieNode,Nothing} = nothing
    right::Union{BitTrieNode,Nothing} = nothing
    is_leaf::Bool = false
end

@kwdef mutable struct BitTrie
    root::Union{BitTrieNode,Nothing} = BitTrieNode()
    size::Int = 0
end

# Adds nodes to the trie to represent the given path
function trie_add!(trie::BitTrie, path::BitVector)
    curr = trie.root
    for i in eachindex(path)
        if path[i]
            if curr.right === nothing
                curr.right = BitTrieNode()
            end
            curr = curr.right
        else
            if curr.left === nothing
                curr.left = BitTrieNode()
            end
            curr = curr.left
        end
        if curr.is_leaf
            return
        end
    end
    if !curr.is_leaf
        trie.size += 1
        curr.is_leaf = true
    end
end

# Checks if the trie contains the given path - used for
function trie_contains(trie::BitTrie, path::BitVector)
    curr = trie.root
    if curr.is_leaf
        return true
    end
    for i in eachindex(path)
        curr = path[i] ? curr.right : curr.left
        if curr === nothing
            return false
        end
        if curr.is_leaf
            return true
        end
    end
    false
end