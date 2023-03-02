@testset verbose=true "Iterators" begin
  @testset "test count_expressions on single Real grammar" begin
    g1 = @cfgrammar begin
        Real = |(1:9)
    end

    @test count_expressions(g1, 1, :Real) == 9

    # Tree depth is equal to 1, so the max depth of 3 does not change the expression count
    @test count_expressions(g1, 3, :Real) == 9
  end

  @testset "test count_expressions on grammar with multiplication" begin
    g1 = @cfgrammar begin
        Real = 1 | 2
        Real = Real * Real 
    end
    # Expressions: [1, 2]  
    @test count_expressions(g1, 1, :Real) == 2

    # Expressions: [1, 2, 1 * 1, 1 * 2, 2 * 1, 2 * 2] 
    @test count_expressions(g1, 2, :Real) == 6
  end

  @testset "test count_expressions on ContextFreeEnumerator" begin
    g1 = @cfgrammar begin
        Real = 1 | 2
        Real = Real * Real 
    end

    cfe = ContextFreeEnumerator(g1, 1, :Real)
    @test count_expressions(cfe) == count_expressions(g1, 1, :Real) == 2

    cfe = ContextFreeEnumerator(g1, 2, :Real)
    @test count_expressions(cfe) == count_expressions(g1, 2, :Real) == 6
  end

  @testset "test count_expressions on different arithmetic operators" begin
    g1 = @cfgrammar begin
        Real = 1
        Real = Real * Real 
    end

    g2 = @cfgrammar begin
      Real = 1
      Real = Real / Real 
    end

    g3 = @cfgrammar begin
      Real = 1
      Real = Real + Real 
    end 

    g4 = @cfgrammar begin
      Real = 1
      Real = Real - Real 
    end 
    
    g5 = @cfgrammar begin
      Real = 1
      Real = Real % Real 
    end 

    g6 = @cfgrammar begin
      Real = 1
      Real = Real \ Real 
    end 

    g7 = @cfgrammar begin
      Real = 1
      Real = Real ^ Real 
    end 

    g8 = @cfgrammar begin
      Real = 1
      Real = -Real * Real 
    end
    
    # E.q for multiplication: [1, 1 * 1, 1 * (1 * 1), (1 * 1) * 1, (1 * 1) * (1 * 1)] 
    @test count_expressions(g1, 3, :Real) == 5
    @test count_expressions(g2, 3, :Real) == 5
    @test count_expressions(g3, 3, :Real) == 5
    @test count_expressions(g4, 3, :Real) == 5
    @test count_expressions(g5, 3, :Real) == 5
    @test count_expressions(g6, 3, :Real) == 5
    @test count_expressions(g7, 3, :Real) == 5
    @test count_expressions(g8, 3, :Real) == 5
  end

  @testset "test count_expressions on grammar with functions" begin
    g1 = @cfgrammar begin
        Real = 1 | 2
        Real = f(Real)                # function call
    end

    # Expressions: [1, 2, f(1), f(2)]
    @test count_expressions(g1, 2, :Real) == 4

    # Expressions: [1, 2, f(1), f(2), f(f(1)), f(f(2))]
    @test count_expressions(g1, 3, :Real) == 6
  end

  @testset "bfs enumerator" begin
    g1 = @cfgrammar begin
      Real = 1 | 2
      Real = Real * Real
    end
    programs = collect(get_bfs_enumerator(g1, 2, :Real))
    @test all(map(t -> depth(t[1]) ≤ depth(t[2]), zip(programs[begin:end-1], programs[begin+1:end])))
    @test length(programs) == count_expressions(g1, 2, :Real)
  end

  @testset "dfs enumerator" begin
    g1 = @cfgrammar begin
      Real = 1 | 2
      Real = Real * Real
    end
    programs = collect(get_dfs_enumerator(g1, 2, :Real))
    @test length(programs) == count_expressions(g1, 2, :Real)
  end

  @testset "probabilistic enumerator" begin
    g₁ = @pcfgrammar begin
      0.2 : Real = |(0:1)
      0.5 : Real = Real + Real
      0.3 : Real = Real * Real 
    end
  
    programs = collect(get_most_likely_first_enumerator(g₁, 2, :Real))
    @test length(programs) == count_expressions(g₁, 2, :Real)
    @test all(map(t -> Grammars.rulenode_log_probability(t[1], g₁) ≥ Grammars.rulenode_log_probability(t[2], g₁), zip(programs[begin:end-1], programs[begin+1:end])))
  end
end