from utils import analyze_data

seed = '958129'
base_exp_dir = '../experiment_results/experiment_0'
output_loc = '../plots/experiment_0'
paper_configs = [[(10, 40), (10, 60), (10, 10), (20, 10), (40, 40), (40, 60)]]
legend_order = [1,0,5,4,3,2,6]
minmax_color = (0.25, 4.5)
config_vars = ["max_time", "generation/max_size"]

# Generate plots for experiment #0, world 958129
analyze_data(base_exp_dir, seed, output_loc, paper_configs, legend_order, minmax_color, config_vars)

seed = '6354'
base_exp_dir = '../experiment_results/experiment_0_2'
output_loc = '../plots/experiment_0'
paper_configs = [[(20, 60), (10, 40), (10, 10), (10, 20), (30, 60), (40, 60)]]
legend_order = [0,1,4,5,2,3,6]
minmax_color = (0.5, 4)
config_vars = ["max_time", "generation/max_size"]

# Generate plots for experiment #0, world 6354
analyze_data(base_exp_dir, seed, output_loc, paper_configs, legend_order, minmax_color, config_vars, plot_mean=True)
