@testset verbose=true "Context-free iterators" begin
  @testset "length on single Real grammar" begin
    g1 = @csgrammar begin
        Real = |(1:9)
    end

    @test length(BFSIterator(g1, :Real, max_depth=1)) == 9

    # Tree depth is equal to 1, so the max depth of 3 does not change the expression count
    @test length(BFSIterator(g1, :Real, max_depth=3)) == 9
  end

  @testset "length on grammar with multiplication" begin
    g1 = @csgrammar begin
        Real = 1 | 2
        Real = Real * Real 
    end
    # Expressions: [1, 2]  
    @test length(BFSIterator(g1, :Real, max_depth=1)) == 2

    # Expressions: [1, 2, 1 * 1, 1 * 2, 2 * 1, 2 * 2] 
    @test length(BFSIterator(g1, :Real, max_depth=2)) == 6
  end

  @testset "length on different arithmetic operators" begin
    g1 = @csgrammar begin
        Real = 1
        Real = Real * Real 
    end

    g2 = @csgrammar begin
      Real = 1
      Real = Real / Real 
    end

    g3 = @csgrammar begin
      Real = 1
      Real = Real + Real 
    end 

    g4 = @csgrammar begin
      Real = 1
      Real = Real - Real 
    end 
    
    g5 = @csgrammar begin
      Real = 1
      Real = Real % Real 
    end 

    g6 = @csgrammar begin
      Real = 1
      Real = Real \ Real 
    end 

    g7 = @csgrammar begin
      Real = 1
      Real = Real ^ Real 
    end 

    g8 = @csgrammar begin
      Real = 1
      Real = -Real * Real 
    end
    
    # E.q for multiplication: [1, 1 * 1, 1 * (1 * 1), (1 * 1) * 1, (1 * 1) * (1 * 1)] 
    @test length(BFSIterator(g1, :Real, max_depth=3)) == 5
    @test length(BFSIterator(g2, :Real, max_depth=3)) == 5
    @test length(BFSIterator(g3, :Real, max_depth=3)) == 5
    @test length(BFSIterator(g4, :Real, max_depth=3)) == 5
    @test length(BFSIterator(g5, :Real, max_depth=3)) == 5
    @test length(BFSIterator(g6, :Real, max_depth=3)) == 5
    @test length(BFSIterator(g7, :Real, max_depth=3)) == 5
    @test length(BFSIterator(g8, :Real, max_depth=3)) == 5
  end

  @testset "length on grammar with functions" begin
    g1 = @csgrammar begin
        Real = 1 | 2
        Real = f(Real)                # function call
    end

    # Expressions: [1, 2, f(1), f(2)]
    @test length(BFSIterator(g1, :Real, max_depth=2)) == 4

    # Expressions: [1, 2, f(1), f(2), f(f(1)), f(f(2))]
    @test length(BFSIterator(g1, :Real, max_depth=3)) == 6
  end

  @testset "bfs enumerator" begin
    g1 = @csgrammar begin
      Real = 1 | 2
      Real = Real * Real
    end
    programs = [freeze_state(p) for p ∈ BFSIterator(g1, :Real, max_depth=2)]
    @test all(map(t -> depth(t[1]) ≤ depth(t[2]), zip(programs[begin:end-1], programs[begin+1:end])))
    
    answer_programs = [
      RuleNode(1),
      RuleNode(2),
      RuleNode(3, [RuleNode(1), RuleNode(1)]),
      RuleNode(3, [RuleNode(1), RuleNode(2)]),
      RuleNode(3, [RuleNode(2), RuleNode(1)]),
      RuleNode(3, [RuleNode(2), RuleNode(2)])
    ]

    @test length(programs) == 6

    @test all(p ∈ programs for p ∈ answer_programs)
  end

  @testset "dfs enumerator" begin
    g1 = @csgrammar begin
      Real = 1 | 2
      Real = Real * Real
    end

    @test length(BFSIterator(g1, :Real, max_depth=2)) == 6
  end

end
