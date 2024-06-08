Below are all the subfolders and their descriptions for everything MineRL related to this branch.

As a reminder, this branch answers the following question:  

_How do we adjust the FrAngel program synthesizer to discover more complex subprograms?_

, within the context of MineRL. All the experiments are based on the `MineRLNavigateDense` environment.

## Folder/file description

- [runexperiments.jl](https://github.com/Herb-AI/HerbSearch.jl/blob/frangel-with-minerl-exploit/src/minecraft/runexperiments.jl): The main starting file for running the experiments.

- [minerl.jl](https://github.com/Herb-AI/HerbSearch.jl/blob/frangel-with-minerl-exploit/src/minecraft/minerl.jl): The file that provides the API for the MineRL environment.

- [experiment_helpers.jl](https://github.com/Herb-AI/HerbSearch.jl/blob/frangel-with-minerl-exploit/src/minecraft/experiment_helpers.jl): An util file containing functions for running the experiments and saving the data.

- [minecraft_grammar_definition.jl](https://github.com/Herb-AI/HerbSearch.jl/blob/frangel-with-minerl-exploit/src/minecraft/minecraft_grammar_definition.jl): The file that contains the grammar used for running the experiments.

- [utils.jl](https://github.com/Herb-AI/HerbSearch.jl/blob/frangel-with-minerl-exploit/src/minecraft/utils.jl): A file containing all utilities not related to any of the above. Includes functions for defining specifications, and pretty logo printing :___)___