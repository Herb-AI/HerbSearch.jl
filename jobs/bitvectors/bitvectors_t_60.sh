#!/bin/sh
#SBATCH --partition=general   # Request partition. Default is 'general'. Select the best partition following the advice on  https://daic.tudelft.nl/docs/manual/job-submission/priorities/#priority-tiers
#SBATCH --qos=short           # Request Quality of Service. Default is 'short' (maximum run time: 4 hours)
#SBATCH --time=2:30:00        # Request run time (wall-clock). Default is 1 minute
#SBATCH --ntasks=30           # Request number of parallel tasks per job. Default is 1
#SBATCH --cpus-per-task=1     # Request number of CPUs (threads) per task. Default is 1 (note: CPUs are always allocated to jobs per 2).
#SBATCH --mem-per-cpu=3GB     # Request memory (MB) per node. Default is 1024MB (1GB). For multiple tasks, specify --mem-per-cpu instead
#SBATCH --output=slurm_%j.out # Set name of output log. %j is the Slurm jobId
#SBATCH --error=slurm_%j.err  # Set name of error log. %j is the Slurm jobId

# Set the SBATCH parameter --time to the expected run time

# Run your script with the `srun` command:
#  problem_name::String, 
#  using_mth::Int,
#  k::Int, 
#  time_out::Int # in seconds

srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 1 1 3600 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 2 1 3600 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 3 1 3600 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 4 1 3600 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 5 1 3600 &

srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 1 2 3600 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 2 2 3600 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 3 2 3600 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 4 2 3600 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 5 2 3600 &

srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 1 4 3600 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 2 4 3600 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 3 4 3600 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 4 4 3600 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 5 4 3600 &

srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 1 8 3600 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 2 8 3600 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 3 8 3600 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 4 8 3600 &
srun --exclusive -N1 -n1 julia --project=HerbSearch experiments.jl bitvectors 5 8 3600 &

wait