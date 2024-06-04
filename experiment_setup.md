# Installing dependencies

To get started, you first need to install all the required Julia packages:

```shell
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

You also have to install MineRL. First make sure you have installed JDK 8. Then you can install MineRL by running:

```shell
julia --project=. src/minecraft/install_minerl.jl
```

# Running experiments

To run the experiment, you have to run the `src/minecraft/benchmark.jl` file. You can specify the experiment number, world seed, number of tries, max. time per try, environment name, and whether to render the environment. For further information you can run:

```shell
julia --project=. src/minecraft/benchmark.jl --help
```

If you want to run an experiment with all the five world seeds and the parameters used in the research paper, you can run the following script:
```shell
./run_experiment.sh <experiment_number>
```
# Results 

The results of the experiments can be found in the `experiments` directory.
