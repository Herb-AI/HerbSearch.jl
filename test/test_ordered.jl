using HerbCore, HerbGrammar, HerbConstraints

@testset verbose=true "Ordered" begin

    function get_grammar_and_constraint1()
        grammar = @csgrammar begin
            Number = 1
            Number = x
            Number = Number + Number
        end
        constraint = Ordered(RuleNode(3, [
            VarNode(:a),
            VarNode(:b)
        ]), [:a, :b])
        return grammar, constraint
    end

    function get_grammar_and_constraint2()
        grammar = @csgrammar begin
            Number = Number + Number
            Number = 1
            Number = -Number
            Number = x
        end
        constraint = Ordered(RuleNode(1, [
            RuleNode(3, [VarNode(:a)]) ,
            RuleNode(3, [VarNode(:b)])
        ]), [:a, :b])
        return grammar, constraint
    end

    @testset "Number of candidate programs" begin
        for (grammar, constraint) in [get_grammar_and_constraint1(), get_grammar_and_constraint2()]
            iter = BFSIterator(grammar, :Number, solver=GenericSolver(grammar, :Number), max_size=6)
            alltrees = 0
            validtrees = 0
            for p ∈ iter
                if check_tree(constraint, p)
                    validtrees += 1
                end
                alltrees += 1
            end

            addconstraint!(grammar, constraint)
            constraint_iter = BFSIterator(grammar, :Number, solver=GenericSolver(grammar, :Number), max_size=6)

            @test validtrees > 0
            @test validtrees < alltrees
            @test length([freeze_state(p) for p ∈ constraint_iter]) == validtrees
        end
    end

    @testset "DomainRuleNode" begin
        #Expressing commutativity of + and * in 2 constraints
        grammar = @csgrammar begin
            Number = 1
            Number = x
            Number = Number + Number
            Number = Number * Number
        end
        constraint1 = Ordered(RuleNode(3, [
            VarNode(:a),
            VarNode(:b)
        ]), [:a, :b])
        constraint2 = Ordered(RuleNode(4, [
            VarNode(:a),
            VarNode(:b)
        ]), [:a, :b])
        addconstraint!(grammar, constraint1)
        addconstraint!(grammar, constraint2)
        
        #Expressing commutativity of + and * using a single constraint (with a DomainRuleNode)
        grammar_domainrulenode = @csgrammar begin
            Number = 1
            Number = x
            Number = Number + Number
            Number = Number - Number
        end
        constraint_domainrulenode = Ordered(DomainRuleNode(BitVector((0, 0, 1, 1)), [
            VarNode(:a),
            VarNode(:b)
        ]), [:a, :b])
        addconstraint!(grammar_domainrulenode, constraint_domainrulenode)
        
        #The number of solutions should be equal in both approaches
        iter = BFSIterator(grammar, :Number, solver=GenericSolver(grammar, :Number), max_size=6)
        iter_domainrulenode = BFSIterator(grammar_domainrulenode, :Number, solver=GenericSolver(grammar, :Number), max_size=6)
        @test length(iter) == length(iter_domainrulenode)
    end
end
