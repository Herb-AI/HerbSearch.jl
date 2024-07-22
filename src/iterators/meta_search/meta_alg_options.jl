supercomputer_run_3averages =  (input_problem::Problem, input_grammar::AbstractGrammar)->begin
generic_run(ParallelCombinatorIterator(ParallelThreads, [VanillaIterator(SASearchIterator(input_grammar, :X, input_problem.spec, mean_squared_error, initial_temperature = 5, temperature_decreasing_factor = 0.99, max_depth = 10), ((time, iteration, cost)->begin
                        time > 6 || iteration > 2000
                    end), input_problem); VanillaIterator(SASearchIterator(input_grammar, :X, input_problem.spec, mean_squared_error, initial_temperature = 5, temperature_decreasing_factor = 0.99, max_depth = 10), ((time, iteration, cost)->begin
                        time > 6 || iteration > 3000
                    end), input_problem)]))
end

supercomputer_run_5averages_moredepth = (input_problem::Problem, input_grammar::AbstractGrammar)->begin
generic_run(SequenceCombinatorIterator([ParallelCombinatorIterator(ParallelThreads, [VanillaIterator(VLSNSearchIterator(input_grammar, :X, input_problem.spec, mean_squared_error, neighbourhood_size = 1), ((time, iteration, cost)->begin
time > 3 || iteration > 2000
end), input_problem); [SequenceCombinatorIterator([VanillaIterator(DFSIterator(input_grammar, :X, max_depth = 4), ((time, iteration, cost)->begin
            time > 3 || iteration > 5000
        end), input_problem); [ParallelCombinatorIterator(ParallelThreads, [VanillaIterator(SASearchIterator(input_grammar, :X, input_problem.spec, mean_squared_error, initial_temperature = 5, temperature_decreasing_factor = 0.96, max_depth = 10), ((time, iteration, cost)->begin
                        time > 3 || iteration > 1000
                    end), input_problem); VanillaIterator(MHSearchIterator(input_grammar, :X, input_problem.spec, mean_squared_error, max_depth = 10), ((time, iteration, cost)->begin
                        time > 3 || iteration > 2000
                    end), input_problem)]); ParallelCombinatorIterator(ParallelThreads, [VanillaIterator(BFSIterator(input_grammar, :X, max_depth = 4), ((time, iteration, cost)->begin
                        time > 4 || iteration > 3000
                    end), input_problem); [VanillaIterator(BFSIterator(input_grammar, :X, max_depth = 4), ((time, iteration, cost)->begin
                            time > 5 || iteration > 2000
                        end), input_problem); VanillaIterator(MHSearchIterator(input_grammar, :X, input_problem.spec, mean_squared_error, max_depth = 10), ((time, iteration, cost)->begin
                            time > 3 || iteration > 5000
                        end), input_problem)]])]]); [SequenceCombinatorIterator([VanillaIterator(SASearchIterator(input_grammar, :X, input_problem.spec, mean_squared_error, initial_temperature = 3, temperature_decreasing_factor = 0.92, max_depth = 10), ((time, iteration, cost)->begin
                time > 6 || iteration > 4000
            end), input_problem); ParallelCombinatorIterator(ParallelThreads, [VanillaIterator(VLSNSearchIterator(input_grammar, :X, input_problem.spec, mean_squared_error, neighbourhood_size = 2), ((time, iteration, cost)->begin
                        time > 4 || iteration > 3000
                    end), input_problem); [VanillaIterator(DFSIterator(input_grammar, :X, max_depth = 4), ((time, iteration, cost)->begin
                            time > 4 || iteration > 3000
                        end), input_problem); VanillaIterator(DFSIterator(input_grammar, :X, max_depth = 4), ((time, iteration, cost)->begin
                            time > 5 || iteration > 5000
                        end), input_problem)]])]); SequenceCombinatorIterator([VanillaIterator(SASearchIterator(input_grammar, :X, input_problem.spec, mean_squared_error, initial_temperature = 4, temperature_decreasing_factor = 0.92, max_depth = 10), ((time, iteration, cost)->begin
                time > 6 || iteration > 3000
            end), input_problem); VanillaIterator(BFSIterator(input_grammar, :X, max_depth = 4), ((time, iteration, cost)->begin
                time > 3 || iteration > 4000
            end), input_problem)])]]]); VanillaIterator(SASearchIterator(input_grammar, :X, input_problem.spec, mean_squared_error, initial_temperature = 6, temperature_decreasing_factor = 0.97, max_depth = 10), ((time, iteration, cost)->begin
time > 5 || iteration > 5000
end), input_problem)]))
end
