@testset "BitTrie" begin
    @testset "basic add and contains" begin
        trie = BitTrie()

        @test !trie_contains(trie, BitVector([true]))

        trie_add!(trie, BitVector([true, false, true]))
        @test trie.size == 1
        
        @test trie_contains(trie, BitVector([true, false, true]))
        @test trie_contains(trie, BitVector([true, false, true, false]))
        @test trie_contains(trie, BitVector([true, false, true, true]))
        @test !trie_contains(trie, BitVector([false]))
        @test !trie_contains(trie, BitVector([true, false, false, true]))
        
        trie_add!(trie, BitVector([false]))
        @test trie.size == 2

        @test trie_contains(trie, BitVector([false]))
        @test trie_contains(trie, BitVector([false, true]))
        @test !trie_contains(trie, BitVector([true]))

        trie_add!(trie, BitVector([false, true]))
        @test trie.size == 2
    end
end