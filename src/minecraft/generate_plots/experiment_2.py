from utils import analyze_data, summarize_data_on_seed

seeds = [958129, 95812, 11248956, 6354, 999999]
base_exp_dir = '../experiment_results/experiment_2'
output_loc = '../plots/experiment_2'
config_vars = ["store_simpler_programs", "generation/use_fragments_chance"]

for s in seeds:
    analyze_data(base_exp_dir, s, output_loc, [], [], (), config_vars)

summarize_data_on_seed(config_vars, [[True, False], [0.3, 0.5]], base_exp_dir, seeds, output_loc)