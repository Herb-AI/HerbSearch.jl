The `shell.sh` contains a wrapper script that will ask for a job name and for the number of cpu cores you would like to run the job with. You can configure your email in the script to get notifications when the job is queued, and finished.
It will then submit the job that executes the `main.jl` file.

The file `training.out` contains the output of the meta-search training job.

The `output_data.json` and `evaluation.out` was created as the result of evaluation.

To run training comment out the line `# get_meta_algorithm() # train algorithm` in `main.jl`.
Likewise, to run evaluation, comment out the line `# run_alg_comparison() # run evaluation` in `main.jl`.