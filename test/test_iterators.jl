using Test
using Search
using Grammars


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
