grammar = @cfgrammar begin
    Num = |(0:10)
    Num = x | (Num + Num)
    Bool = Num == Num
    Num = (
        if Bool
            Num
        else
            Num
        end
    )
    Angelic = update_✝_angelic_path
end

st = SymbolTable(grammar)
st[:update_✝γ_path] = update_✝γ_path

@testset "test_code_paths" begin
    @testset "0-true flows" begin
        code_paths = Vector{BitVector}()
        get_code_paths!(0, BitVector(), BitTrie(), code_paths, 2)
        @test code_paths == [[]]
    end

    @testset "1-true flows" begin
        code_paths = Vector{BitVector}()
        get_code_paths!(1, BitVector(), BitTrie(), code_paths, 2)
        @test code_paths == BitVector[[true], [false, true]]
    end

    @testset "2-true flows" begin
        code_paths = Vector{BitVector}()
        get_code_paths!(2, BitVector(), BitTrie(), code_paths, 3)
        @test code_paths == [[true, true], [true, false, true], [true, false, false, true]]
    end

    @testset "2-true flows, some visited" begin
        code_paths = Vector{BitVector}()
        visited = BitTrie()
        trie_add!(visited, BitVector([true]))
        get_code_paths!(2, BitVector(), visited, code_paths, 3)
        @test code_paths == [[false, true, true], [false, true, false, true], [false, true, false, false, true]]
    end
end

@testset "test_expression_angelic_modification_basic" begin
    expr = :(
        if update_✝γ_path(✝γ_code_path, ✝γ_actual_code_path)
            3
        else
            2
        end
    )

    @testset "falsy evaluation" begin
        opath = CodePath(BitVector([false]), 0)
        apath = BitVector()

        angelic_expr = quote
            ✝γ_code_path = $opath
            ✝γ_actual_code_path = $apath
            $expr
        end
        out = execute_on_input(st, angelic_expr, Dict(:x => 0))

        @test out == 2
        @test apath == [false]
    end

    @testset "truthy evaluation" begin
        opath = CodePath(BitVector([true, true]), 0)
        apath = BitVector()

        angelic_expr = quote
            ✝γ_code_path = $opath
            ✝γ_actual_code_path = $apath
            $expr
        end
        out = execute_on_input(st, angelic_expr, Dict(:x => 0))

        @test out == 3
        @test apath == [true] # Note how the attempted path is two 1s, but actual - just one (only one if-statement)
    end
end

@testset "test_expression_angelic_modification_error" begin
    st[:error] = error
    expr = :(
        if update_✝γ_path(✝γ_code_path, ✝γ_actual_code_path)
            error("hi")
            if update_✝γ_path(✝γ_code_path, ✝γ_actual_code_path)
                10
            else
                0
            end
        else
            2
        end
    )

    @testset "falsy evaluation" begin
        opath = CodePath(BitVector([false]), 0)
        apath = BitVector()

        angelic_expr = quote
            ✝γ_code_path = $opath
            ✝γ_actual_code_path = $apath
            $expr
        end
        out = execute_on_input(st, angelic_expr, Dict(:x => 0))

        @test out == 2
        @test apath == [false]
    end

    @testset "truthy evaluation" begin
        opath = CodePath(BitVector([true, true]), 0)
        apath = BitVector()

        angelic_expr = quote
            ✝γ_code_path = $opath
            ✝γ_actual_code_path = $apath
            $expr
        end

        @test_throws Exception execute_on_input(st, angelic_expr, Dict(:x => 0)) # truthy case should throw an error
        @test apath == [true] # and not enter the if-statement afterwards
    end
end