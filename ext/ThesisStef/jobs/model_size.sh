#!/bin/sh
#SBATCH --partition=general   # Request partition. Default is 'general'. Select the best partition following the advice on  https://daic.tudelft.nl/docs/manual/job-submission/priorities/#priority-tiers
#SBATCH --qos=medium           # Request Quality of Service. Default is 'short' (maximum run time: 4 hours)
#SBATCH --time=8:00:00        # Request run time (wall-clock). Default is 1 minute
#SBATCH --ntasks=1           # Request number of parallel tasks per job. Default is 1
#SBATCH --cpus-per-task=4     # Request number of CPUs (threads) per task. Default is 1 (note: CPUs are always allocated to jobs per 2).
#SBATCH --mem-per-cpu=4GB     # Request memory (MB) per node. Default is 1024MB (1GB). For multiple tasks, specify --mem-per-cpu instead
#SBATCH --output=model_size_%j.out # Set name of output log. %j is the Slurm jobId
#SBATCH --error=model_size_%j.err  # Set name of error log. %j is the Slurm jobId

# Set the SBATCH parameter --time to the expected run time

srun julia --project=HerbSearch experiment.jl 2 2