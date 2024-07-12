## How to run
1. `git pull` to fetch the latest changes on the `meta-search` branch. Run `git reset --hard` to discard any changes that prevent the pull. Alternatively, if you do not want to lose the local changes you can run `git stash`
2. Open the `HerbSearch` folder in vscode and run `julia --project` in the terminal. This will open a julia REPL with the `HerbSearch` project activated.
3. Enter package mode by typing `]`. This should show `(HerbSearch) pkg>`
4. Now run  `add HerbGrammar#add-typechecking-for-insert!` to add a dependency to `add-typechecking-for-insert!` branch of `HerbGrammar` where I made some changes that are required by meta-search.
5. Run `resolve` and `instantiate` to install the dependencies from the project.
6. Run `precompile` to make sure the setup works.
7. Check the depenendecies of the project by running `status`. It should like similar to this
```julia
  [5218b696] Configurations v0.17.6
  [864edb3b] DataStructures v0.18.20
⌃ [1fa96474] HerbConstraints v0.2.0
  [2b23ba43] HerbCore v0.3.0
  [4ef9e186] HerbGrammar v0.3.0 `https://github.com/Herb-AI/HerbGrammar.jl.git#add-typechecking-for-insert!`
  [5bbddadd] HerbInterpret v0.1.3
  [6d54aada] HerbSpecification v0.1.0
  [d8e11817] MLStyle v0.4.17
  [2913bbd2] StatsBase v0.34.3
  [56ddb016] Logging
  [9a3f8284] Random
```
8. Exit the REPL by pressing `Ctrl+D`

## Run tests
Since some tests check if thread-parallelism works you need to make sure that you initialize Julia with some threads (the default is 1) to pass the tests.
1. In the `HerbSearch` folder run `julia --project --threads 16`.
2. Enter package mode using `]`
3. Type `test`
4. Wait and hopefully all the tests pass. If a few tests fail regarding some `abs(actual_runtime - desired_runtime) <= threshold` assertions is fine, it just means that there is fluctuation in the timing of tests but the setup works.

 
## Files
- [combinators.jl](./combinators.jl) : defines the parallel and sequence combinators
- [meta_arithmetic_grammar.jl](./meta_arithmetic_grammar.jl) : defines the arithmetic grammar used for evaluating the meta serach as well as the training problems and the evaluation problems
- [meta_grammar_definition.jl](./meta_grammar_definition.jl) : defines the meta_grammar (i.e. what algorithms can be used and how can they be combined)
- [main.jl](./main.jl) : loads configuration from the [configuration.toml](./configuration.toml) file and runs meta_search with the fitness configured. This file is the _main_ file to run for experiments.
- [configuration.jl](./configuration.jl) : code responsible for loading the configuration file into Julia structs.

- [meta_search.jl](./meta_search.jl) : defines the configuration structs and the fitness function for evaluating meta programs. It also defines a function `run_meta_search` configures a genetic search algorithm to run on the meta grammar.
- [other.jl](./other.jl) : defines useful functions for plotting.
- [run_algorithm.jl](./run_algorithm.jl) : runs algorithm on the test problems multiple times to account for randomness. It reports the number of correctly solved problems for each run.


## Changes
- Integrate BFS and DFS into the meta-search
- Refactor the grammar with nice easy to read structs.
- VLNS now instead of enumerating programs until a depth will use BFS to fill a "hole" for a fixed number of iterations called `neighbourhood_size` which replaces the old `vlns_neighbourhood_depth` variable.
