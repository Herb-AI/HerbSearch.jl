#!/bin/sh
#SBATCH --partition=general   # Request partition. Default is 'general'. Select the best partition following the advice on  https://daic.tudelft.nl/docs/manual/job-submission/priorities/#priority-tiers
#SBATCH --qos=short           # Request Quality of Service. Default is 'short' (maximum run time: 4 hours)
#SBATCH --time=2:00:00        # Request run time (wall-clock). Default is 1 minute
#SBATCH --ntasks=20           # Request number of parallel tasks per job. Default is 1
#SBATCH --cpus-per-task=1     # Request number of CPUs (threads) per task. Default is 1 (note: CPUs are always allocated to jobs per 2).
#SBATCH --mem-per-cpu=3GB     # Request memory (MB) per node. Default is 1024MB (1GB). For multiple tasks, specify --mem-per-cpu instead
#SBATCH --output=slurm_%j.out # Set name of output log. %j is the Slurm jobId
#SBATCH --error=slurm_%j.err  # Set name of error log. %j is the Slurm jobId

# Set the SBATCH parameter --time to the expected run time

# Run your script with the `srun` command:
    # problem_name::String, 
    # using_mth::Int,
    # k::Int, 
    # time_out::Int # in seconds

srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels_baseline &

srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 1 1 1800 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 2 1 1800 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 3 1 1800 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 4 1 1800 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 5 1 1800 &

srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 1 2 1800 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 2 2 1800 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 3 2 1800 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 4 2 1800 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 5 2 1800 &

srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 1 4 1800 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 2 4 1800 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 3 4 1800 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 4 4 1800 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 5 4 1800 &

srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 1 8 1800 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 2 8 1800 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 3 8 1800 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 4 8 1800 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl pixels 5 8 1800 &


wait