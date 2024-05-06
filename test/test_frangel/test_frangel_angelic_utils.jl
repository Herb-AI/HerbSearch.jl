g = @cfgrammar begin
    Num = |(0:10)
end

st = SymbolTable(g)
st[:update_✝γ_path] = update_✝γ_path

@testset "test_expression_angelic_modification_basic" begin
    expr = :(if update_✝γ_path(✝γ_code_path, ✝γ_actual_code_path) 3 else 2 end)

    @testset "falsy evaluation" begin
        opath = Vector{Char}(['0'])
        apath = Vector{Char}([])

        angelic_expr = quote
            ✝γ_code_path = $opath
            ✝γ_actual_code_path = $apath
            $expr
        end
        out = execute_on_input(st, angelic_expr, Dict(:x => 0)) 

        @test out == 2
        @test apath == ['0']
    end

    @testset "truthy evaluation" begin
        opath = Vector{Char}(['1', '1'])
        apath = Vector{Char}([])

        angelic_expr = quote
            ✝γ_code_path = $opath
            ✝γ_actual_code_path = $apath
            $expr
        end
        out = execute_on_input(st, angelic_expr, Dict(:x => 0)) 

        @test out == 3
        @test apath == ['1'] # Note how the attempted path is two 1s, but actual - just one (only one if-statement)
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
        opath = Vector{Char}(['0'])
        apath = Vector{Char}([])

        angelic_expr = quote
            ✝γ_code_path = $opath
            ✝γ_actual_code_path = $apath
            $expr
        end
        out = execute_on_input(st, angelic_expr, Dict(:x => 0)) 

        @test out == 2
        @test apath == ['0']
    end

    @testset "truthy evaluation" begin
        opath = Vector{Char}(['1', '1'])
        apath = Vector{Char}([])

        angelic_expr = quote
            ✝γ_code_path = $opath
            ✝γ_actual_code_path = $apath
            $expr
        end

        @test_throws Exception execute_on_input(st, angelic_expr, Dict(:x => 0)) # truthy case should throw an error
        @test apath == ['1'] # and not enter the if-statement afterwards
    end
end