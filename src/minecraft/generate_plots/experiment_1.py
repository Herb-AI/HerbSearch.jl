from utils import analyze_data, summarize_data_on_config

seed = 958129
base_exp_dir = '../experiment_results/experiment_1'
output_loc = '../plots/experiment_1'
paper_configs = [
    # Showcase changes in use_fragments_chance
    [(0.65, 0.65, 0), (0.8, 0.65, 0.0), (0.9, 0.65, 0.0), (0.3, 0.65, 0.0)], [(0.65, 0.3, 0), (0.8, 0.3, 0.0), (0.9, 0.3, 0.0), (0.3, 0.3, 0.0)], [(0.65, 0.9, 0), (0.8, 0.9, 0.0), (0.9, 0.9, 0.0), (0.3, 0.9, 0.0)],
    # Showcase changes in use_entire_fragment_chance
    [(0.3, 0.3, 0.0), (0.3, 0.65, 0.0), (0.3, 0.9, 0.0)], [(0.65, 0.3, 0.0), (0.65, 0.65, 0.0), (0.65, 0.9, 0.0)], [(0.8, 0.3, 0.0), (0.8, 0.65, 0.0), (0.8, 0.9, 0.0)], [(0.9, 0.3, 0.0), (0.9, 0.65, 0.0), (0.9, 0.9, 0.0)],
    # Showcase changes in gen_similar_prob_new
    [(0.3, 0.65, 0), (0.3, 0.65, 0.25), (0.3, 0.65, 0.5), (0.3, 0.65, 0.75)], [(0.3, 0.3, 0), (0.3, 0.3, 0.25), (0.3, 0.3, 0.5), (0.3, 0.3, 0.75)], [(0.3, 0.9, 0), (0.3, 0.9, 0.25), (0.3, 0.9, 0.5), (0.3, 0.9, 0.75)]]
legend_order = [0, 1, 2, 3]
minmax_color = (0.25, 4.5)
config_vars = ["generation/use_fragments_chance", "generation/use_entire_fragment_chance", "generation/gen_similar_prob_new"]

# Generate plots for experiment #1, world 958129
analyze_data(base_exp_dir, seed, output_loc, paper_configs, legend_order, minmax_color, config_vars)

possible_vals = [[0.3, 0.65, 0.8, 0.9], [0.3, 0.65, 0.9], [0, 0.25, 0.5, 0.75]]
summarize_data_on_config(config_vars, possible_vals, base_exp_dir, seed, output_loc)