RefactorExt = Base.get_extension(HerbSearch, :RefactorExt)
using .RefactorExt: read_last_witness_from_json

test_input1 = """
{
  "Solver": "clingo version 5.7.1",
  "Input": [
    "/home/username/Study/Herb/HerbSearch.jl/src/grammar_refactor/model.lp","-"
  ],
  "Call": [
    {
      "Witnesses": [
        {
          "Value": [
            
          ],
          "Costs": [
            0
          ]
        },
        {
          "Value": [
            "assign(46,0)"
          ],
          "Costs": [
            -1
          ]
        },
        {
          "Value": [
            "assign(51,2)", "assign(49,0)"
          ],
          "Costs": [
            -2
          ]
        },
        {
          "Value": [
            "assign(56,1)", "assign(55,0)", "assign(57,2)"
          ],
          "Costs": [
            -3
          ]
        }
      ]
    }
  ],
  "Result": "OPTIMUM FOUND",
  "Models": {
    "Number": 4,
    "More": "no",
    "Optimum": "yes",
    "Optimal": 1,
    "Costs": [
      -3
    ]
  },
  "Calls": 1,
  "Time": {
    "Total": 0.033,
    "Solve": 0.000,
    "Model": 0.000,
    "Unsat": 0.000,
    "CPU": 0.002
  }
}
"""
test_input2 = """
{
  "Solver": "clingo version 5.7.1",
  "Input": [
    "/home/username/Study/Herb/HerbSearch.jl/src/grammar_refactor/model.lp","-"
  ],
  "Call": [
    {
      "Witnesses": [
        {
          "Value": [
            
          ],
          "Costs": [
            0
          ]
        },
        {
          "Value": [
            "assign(50,1)"
          ],
          "Costs": [
            -1
          ]
        },
        {
          "Value": [
            "assign(57,2)", "assign(56,1)"
          ],
          "Costs": [
            -2
          ]
        },
        {
          "Value": [
            "assign(55,6)", "assign(53,4)", "assign(50,1)"
          ],
          "Costs": [
            -3
          ]
        },
        {
          "Value": [
            "assign(55,6)", "assign(53,4)", "assign(57,2)", "assign(56,1)"
          ],
          "Costs": [
            -4
          ]
        },
        {
          "Value": [
            "assign(55,3)", "assign(53,1)", "assign(12,4)", "assign(10,0)", "assign(13,5)", "assign(14,6)"
          ],
          "Costs": [
            -6
          ]
        },
        {
          "Value": [
            "assign(60,5)", "assign(59,4)", "assign(61,6)", "assign(60,2)", "assign(59,1)", "assign(61,3)", "assign(7,0)"
          ],
          "Costs": [
            -7
          ]
        }
      ]
    }
  ],
  "Result": "OPTIMUM FOUND",
  "Models": {
    "Number": 7,
    "More": "no",
    "Optimum": "yes",
    "Optimal": 1,
    "Costs": [
      -7
    ]
  },
  "Calls": 1,
  "Time": {
    "Total": 0.002,
    "Solve": 0.000,
    "Model": 0.000,
    "Unsat": 0.000,
    "CPU": 0.002
  }
}
"""

@testset verbose=true "Parse Clingo Output" begin
    @testset "Parse Clingo Output Small" begin
        expected_output = Any["assign(56,1)","assign(55,0)","assign(57,2)"]
        output = read_last_witness_from_json(test_input1)
        @test output == expected_output
    end

    @testset "Parse Clingo Output Large" begin
        expected_output = Any["assign(60,5)", "assign(59,4)", "assign(61,6)", "assign(60,2)", "assign(59,1)", "assign(61,3)", "assign(7,0)"]
        output = read_last_witness_from_json(test_input2)
        @test output == expected_output
    end
end


