@testset verbose=true "Context-sensitive iterators" begin
    @testset "test count_expressions on single Real grammar" begin
      g1 = @csgrammar begin
          Real = |(1:9)
      end
  
      @test count_expressions(g1, 1, typemax(Int), :Real) == 9
  
      # Tree depth is equal to 1, so the max depth of 3 does not change the expression count
      @test count_expressions(g1, 3, typemax(Int), :Real) == 9
    end
  
    @testset "test count_expressions on grammar with multiplication" begin
      g1 = @csgrammar begin
          Real = 1 | 2
          Real = Real * Real 
      end
      # Expressions: [1, 2]  
      @test count_expressions(g1, 1, typemax(Int), :Real) == 2
  
      # Expressions: [1, 2, 1 * 1, 1 * 2, 2 * 1, 2 * 2] 
      @test count_expressions(g1, 2, typemax(Int), :Real) == 6
    end
  
    @testset "test count_expressions on different arithmetic operators" begin
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
      @test count_expressions(g1, 3, typemax(Int), :Real) == 5
      @test count_expressions(g2, 3, typemax(Int), :Real) == 5
      @test count_expressions(g3, 3, typemax(Int), :Real) == 5
      @test count_expressions(g4, 3, typemax(Int), :Real) == 5
      @test count_expressions(g5, 3, typemax(Int), :Real) == 5
      @test count_expressions(g6, 3, typemax(Int), :Real) == 5
      @test count_expressions(g7, 3, typemax(Int), :Real) == 5
      @test count_expressions(g8, 3, typemax(Int), :Real) == 5
    end
  
    @testset "test count_expressions on grammar with functions" begin
      g1 = @csgrammar begin
          Real = 1 | 2
          Real = f(Real)                # function call
      end
  
      # Expressions: [1, 2, f(1), f(2)]
      @test count_expressions(g1, 2, typemax(Int), :Real) == 4
  
      # Expressions: [1, 2, f(1), f(2), f(f(1)), f(f(2))]
      @test count_expressions(g1, 3, typemax(Int), :Real) == 6
    end
  
    @testset "bfs enumerator" begin
      g1 = @csgrammar begin
        Real = 1 | 2
        Real = Real * Real
      end
      programs = collect(get_bfs_enumerator(g1, 2, typemax(Int), :Real))
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
      programs = collect(get_dfs_enumerator(g1, 2, typemax(Int), :Real))
      @test length(programs) == count_expressions(g1, 2, typemax(Int), :Real)
    end
  
    @testset "probabilistic enumerator" begin
      g₁ = @pcsgrammar begin
        0.2 : Real = |(0:1)
        0.5 : Real = Real + Real
        0.3 : Real = Real * Real 
      end
    
      programs = collect(get_most_likely_first_enumerator(g₁, 2, typemax(Int), :Real))
      @test length(programs) == count_expressions(g₁, 2, typemax(Int), :Real)
      @test all(map(t -> rulenode_log_probability(t[1], g₁) ≥ rulenode_log_probability(t[2], g₁), zip(programs[begin:end-1], programs[begin+1:end])))
    end

    @testset "ComesAfter constraint" begin
        g₁ = @csgrammar begin
            Real = |(1:3)
            Real = Real + Real
        end

        constraint = ComesAfter(1, [4])
        addconstraint!(g₁, constraint)
        programs = collect(get_bfs_enumerator(g₁, 2, typemax(Int), :Real))
        @test RuleNode(1) ∉ programs
        @test RuleNode(4, [RuleNode(1), RuleNode(1)]) ∈ programs
    end

    @testset "Ordered constraint" begin
        g₁ = @csgrammar begin
            Real = |(1:3)
            Real = Real + Real
        end
        constraint = OrderedPath([2, 1])
        addconstraint!(g₁, constraint)
        programs = collect(get_bfs_enumerator(g₁, 2, typemax(Int), :Real))

        @test RuleNode(4, [RuleNode(1), RuleNode(2)]) ∉ programs
        @test RuleNode(4, [RuleNode(2), RuleNode(1)]) ∈ programs

        @test RuleNode(1) ∉ programs
        @test RuleNode(2) ∈ programs

    end

    @testset "Forbidden constraint" begin
        g₁ = @csgrammar begin
            Real = |(1:3)
            Real = Real + Real
        end
        constraint = ForbiddenPath([4, 1])
        addconstraint!(g₁, constraint)
        programs = collect(get_bfs_enumerator(g₁, 2, typemax(Int), :Real))

        @test RuleNode(4, [RuleNode(1), RuleNode(2)]) ∉ programs
        @test RuleNode(4, [RuleNode(2), RuleNode(1)]) ∉ programs

        @test RuleNode(1) ∈ programs
        @test RuleNode(2) ∈ programs
    end
end
  