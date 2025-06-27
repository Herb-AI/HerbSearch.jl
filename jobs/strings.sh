#!/bin/sh
#SBATCH --partition=mempry         # Request partition. Select the best partition following the advice on  https://daic.tudelft.nl/docs/manual/job-submission/priorities/#priority-tiers
#SBATCH --time=4:00:00              # Request run time (wall-clock). Default is 1 minute
#SBATCH --ntasks=2                  # Request number of parallel tasks per job. Default is 1
#SBATCH --cpus-per-task=1           # Request number of CPUs (threads) per task. Default is 1 (note: CPUs are always allocated to jobs per 2).
#SBATCH --mem-per-cpu=12GB           # Request memory (MB) per node. Default is 1024MB (1GB). For multiple tasks, specify --mem-per-cpu instead
#SBATCH --output=slurm_%j.out       # Set name of output log. %j is the Slurm jobId
#SBATCH --error=slurm_%j.err        # Set name of error log. %j is the Slurm jobId

# Set the SBATCH parameter --time to the expected run time

# Run your script with the `srun` command:
#  problem_name::String,
#  using_mth::Int,
#  k::Int,
#  time_out::Int # in seconds

srun --exclusive -N1 -n1 julia --project=HerbSearch run_benchmark.jl strings 15 10 100 regular+aulile_edit_distance &
srun --exclusive -N1 -n1 julia --project=HerbSearch run_benchmark.jl strings 15 10 250 regular+aulile_edit_distance &
srun --exclusive -N1 -n1 julia --project=HerbSearch run_benchmark.jl strings 15 10 500 regular+aulile_edit_distance &
srun --exclusive -N1 -n1 julia --project=HerbSearch run_benchmark.jl strings 15 10 1000 regular+aulile_edit_distance &
srun --exclusive -N1 -n1 julia --project=HerbSearch run_benchmark.jl strings 15 10 2000 regular+aulile_edit_distance &
srun --exclusive -N1 -n1 julia --project=HerbSearch run_benchmark.jl strings 15 10 4000 regular+aulile_edit_distance &
srun --exclusive -N1 -n1 julia --project=HerbSearch run_benchmark.jl strings 15 10 8000 regular+aulile_edit_distance &
srun --exclusive -N1 -n1 julia --project=HerbSearch run_benchmark.jl strings 15 10 16000 regular+aulile_edit_distance &
srun --exclusive -N1 -n1 julia --project=HerbSearch run_benchmark.jl strings 15 10 32000 regular+aulile_edit_distance &
srun --exclusive -N1 -n1 julia --project=HerbSearch run_benchmark.jl strings 15 10 64000 regular+aulile_edit_distance &
srun --exclusive -N1 -n1 julia --project=HerbSearch run_benchmark.jl strings 15 10 128000 regular+aulile_edit_distance &
srun --exclusive -N1 -n1 julia --project=HerbSearch run_benchmark.jl strings 15 10 256000 regular+aulile_edit_distance &
srun --exclusive -N1 -n1 julia --project=HerbSearch run_benchmark.jl strings 15 10 512000 regular+aulile_edit_distance &
srun --exclusive -N1 -n1 julia --project=HerbSearch run_benchmark.jl strings 15 10 1024000 regular+aulile_edit_distance &

wait
