grammar = @HerbGrammar.cfgrammar begin
               # 1         # 2
    Program = Operation | (Program; Operation)

                 # 3           # 4          # 5               # 6               # 7      # 8                               # 9  
    Operation = moveRight() | moveLeft() | makeUppercase() | makeLowercase() | drop() | IF(Condition, Program, Program) | WHILE(Condition, Program)

                 # 10      # 11         # 12        # 13           # 14         # 15            # 16            # 17               # 18            # 19               # 20         # 21           # 22        # 23
    Condition = atEnd() | notAtEnd() | atStart() | notAtStart() | isLetter() | isNotLetter() | isUppercase() | isNotUppercase() | isLowercase() | isNotLowercase() | isNumber() | isNotNumber() | isSpace() | isNotSpace()
end
