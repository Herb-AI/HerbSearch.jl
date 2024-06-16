Below are all the subfolders and their descriptions for everything MineRL related to this branch.

As a reminder, this branch answers the following question:  

_How do we adjust the FrAngel program synthesizer to discover more complex subprograms?_

, within the context of MineRL. All the experiments are based on the `MineRLNavigateDense` environment.

## Folder/file description

- [experiment_results](https://github.com/Herb-AI/HerbSearch.jl/blob/frangel-with-minerl-exploit/src/minecraft/experiment_results): All gathered experiment data, in the form of JSON files containing FrAngel configuration, seeds, grammar, and fragment/program complexities for each attempt. 

- [generate_plots](https://github.com/Herb-AI/HerbSearch.jl/blob/frangel-with-minerl-exploit/src/minecraft/generate_plots): A folder containing all Python utilities for generating the plots. Make sure you run the scripts from this working folder!

- [plots](https://github.com/Herb-AI/HerbSearch.jl/blob/frangel-with-minerl-exploit/src/minecraft/plots): A folder containing all plots generated from experiments. For each experiment, we have two versions: The full one containing all of the data, and a compact one to summarize the findings, and be used in the report.

- [runexperiments.jl](https://github.com/Herb-AI/HerbSearch.jl/blob/frangel-with-minerl-exploit/src/minecraft/runexperiments.jl): The main starting file for running the experiments.

- [minerl.jl](https://github.com/Herb-AI/HerbSearch.jl/blob/frangel-with-minerl-exploit/src/minecraft/minerl.jl): The file that provides the API for the MineRL environment.

- [experiment_helpers.jl](https://github.com/Herb-AI/HerbSearch.jl/blob/frangel-with-minerl-exploit/src/minecraft/experiment_helpers.jl): An util file containing helper functions for running the experiments and saving the data.

- [minecraft_grammar_definition.jl](https://github.com/Herb-AI/HerbSearch.jl/blob/frangel-with-minerl-exploit/src/minecraft/minecraft_grammar_definition.jl): The file that contains the grammar used for running the experiments.

- [utils.jl](https://github.com/Herb-AI/HerbSearch.jl/blob/frangel-with-minerl-exploit/src/minecraft/utils.jl): A file containing all utilities not related to any of the above. Includes functions for defining specifications, and pretty logo printing :___)___