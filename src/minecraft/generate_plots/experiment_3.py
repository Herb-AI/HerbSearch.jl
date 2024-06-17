from utils import analyze_data, summarize_data_on_seed

seeds = [958129, 95812, 11248956, 6354, 999999]
base_exp_dir = '../experiment_results/experiment_3'
output_loc = '../plots/experiment_3'
config_vars = ["recursion_depth"]

for s in seeds:
    analyze_data(base_exp_dir, s, output_loc, [], [], (), config_vars)

summarize_data_on_seed(config_vars, [[2, 3, 4]], base_exp_dir, seeds, output_loc)