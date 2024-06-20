import numpy as np 
import matplotlib.pyplot as plt 
import matplotlib
from matplotlib import container
import json 
import re

GLOBAL_SEEDS_FOR_EXPERIMENTS = [1234, 4123, 4231, 9581, 9999] # taken from experiment_helpers.jl
EXPERIMENT_PATH = "src/minecraft/experiments"
PROBE_EXPERIMENT_PATH = f"{EXPERIMENT_PATH}/probe"
FRANGEL_EXPERIMENT_PATH = f"{EXPERIMENT_PATH}/frangel"

def compute_statistics_of_attempt(attempt_list, key_total_time="total_time", max_runtime=300):
    solved_attempts_runtime = [min(attempt[key_total_time], max_runtime) for attempt in attempt_list]
    # if np.mean(solved_attempts_runtime) == max_runtime:
    #     solved_attempts_runtime = []

    return {
        "nr_solved":  np.count_nonzero([1 for solve in attempt_list if solve["solved"]]),
        "solve_times":   solved_attempts_runtime,
        "best_reward": [solve.get('best_reward','') for solve in attempt_list]
    }
def read_experiment_alternating_random(experiment_name, seeds):
    solved_time_data = []
    for seed_nr in seeds:
        with open(f"{PROBE_EXPERIMENT_PATH}/{experiment_name}/Seed_{seed_nr}.json","r") as f:
            json_data = json.load(f)
            run_data = json_data["data"]
            mean_solved_time = compute_statistics_of_attempt(run_data)
            solved_time_data.append(mean_solved_time)
    return solved_time_data

def read_experiment_cycles(seed_numbers, cycle_length):
    solved_time_data = []
    for seed_nr in seed_numbers:
        with open(f"{PROBE_EXPERIMENT_PATH}/experiment_cycles_new/Seed_{seed_nr}.json","r") as f:
            json_data = json.load(f)
            run_data = json_data["data"]
            for cycle_data in run_data:
                for (key, value) in cycle_data.items():
                    file_cycle_length = int(re.findall(r'\d+', key)[0])
                    if file_cycle_length == cycle_length:
                        mean_solved_time = compute_statistics_of_attempt(value)
                        solved_time_data.append(mean_solved_time)
    return solved_time_data

def read_experiment_full_random():
    solved_time_data = []
    with open(f"{PROBE_EXPERIMENT_PATH}/experiment_pure_random/experiment.json","r") as f:
        json_data = json.load(f)
        for world in json_data:
            run_data = world["tries_data"]
            mean_solved_time = compute_statistics_of_attempt(run_data)
            solved_time_data.append(mean_solved_time)
    return solved_time_data

def read_experiment_frangel_filtering_for(seeds, experiment_name, filter_lambda):
    solved_time_data = []
    for seed in seeds: 
        filename = f"{FRANGEL_EXPERIMENT_PATH}/{experiment_name}/Seed_{seed}.json"
        with open(filename,"r") as f:
            json_data = json.load(f)
            run_data = json_data["tries_data"]
            fragement_prob_data = [attempt for attempt in run_data if filter_lambda(attempt)]
            solved_time_data.append(compute_statistics_of_attempt(fragement_prob_data, key_total_time="runtime", max_runtime=200))
    return solved_time_data


def create_bar_data_frangel(seeds, use_max_time = False, use_fragement_prob = False, use_gen_similar_prob_new = False, use_entire_fragment_chance = False):
    bar_data_array = []
    if use_fragement_prob:
        for fragement_prob in [0.2, 0.4, 0.6, 0.8]:
            filter_lambda = lambda attempt: attempt["frangel_config"]["generation"]["use_fragments_chance"] == fragement_prob
            bar_data_array.append({
                "label": f"$fragprob = {fragement_prob}$",
                "data": read_experiment_frangel_filtering_for(seeds, experiment_name="experiment_different_use_fragement_probabilities", filter_lambda=filter_lambda)
            })

    if use_max_time:
        for max_time in [5, 10, 20, 30]:
            filter_lambda = lambda attempt: attempt["frangel_config"]["max_time"] == max_time
            bar_data_array.append({
                "label": f"$maxtime = {max_time}$",
                "data": read_experiment_frangel_filtering_for(seeds, experiment_name="experiment_different_frangel_max_time", filter_lambda=filter_lambda)
            })

    if use_gen_similar_prob_new:
        for gen_similar_prob_new in  [0, 0.1, 0.2, 0.4, 0.5]:
            filter_lambda = lambda attempt: attempt["frangel_config"]["generation"]["gen_similar_prob_new"] == gen_similar_prob_new
            bar_data_array.append({
                "label": f" $mutation\_prob = {gen_similar_prob_new}$",
                "data": read_experiment_frangel_filtering_for(seeds, experiment_name="experiment_differrent_probabilities_of_mutating_programs", filter_lambda=filter_lambda)
            })
    if use_entire_fragment_chance:
        for use_entire_fragment_chance in  [0, 0.2, 0.4, 0.6, 0.8]:
            filter_lambda = lambda attempt: attempt["frangel_config"]["generation"]["use_entire_fragment_chance"] == use_entire_fragment_chance
            bar_data_array.append({
                "label": f" $use\_entire\_frg\_chance = {use_entire_fragment_chance}$",
                "data": read_experiment_frangel_filtering_for(seeds, experiment_name="experiment_different_use_entire_fragment_chance", filter_lambda=filter_lambda)
            })


    return bar_data_array

def create_probe_data(seeds, add_random = True, all_in_plot = False):
    bar_data_array = []
    
    if not add_random or all_in_plot:
        # add bars for cycle lengths
        for i in range(5,9):
            bar_data_array.append({
                "label": f"Cycle length {i}",
                "data": read_experiment_cycles(seeds, i)
            })
        
    if add_random or all_in_plot :
        probabilities = [0.3, 0.5, 1]
        for prob in probabilities:
            bar_data_array.append({
                "label": f"RND $p={prob}$",
                "data": read_experiment_alternating_random(experiment_name=f"experiment_alternating_random_new_{prob}",seeds=seeds)
            })
    return bar_data_array

def plot_bar_data_array(bar_data_array, seeds, ymax = 300, barWidth = 0.2, plot_box_plot = True, plot_maximum = False, plot_min_max_avg = False, statistic = 'solve_times', ylabel='Runtime of solving MineRLNavigateDense-v0', top=0.808, bottom=0.092, left=0.113, right=0.995, hspace=0.2, wspace=0.2):
    plt.figure(figsize=(12, 12))

    box_positions = []
    for (i, bar_data) in enumerate(bar_data_array):
        default_bar_spacing = np.arange(len(bar_data["data"]))
        bar = [-0.5 + barWidth + x + barWidth * 2 * i for x in default_bar_spacing]
        box_positions.append(bar)


    labels = [bar_data["label"] for bar_data in bar_data_array]
    box_plots = []

    for (index, (bar_data, box_position)) in enumerate(zip(bar_data_array, box_positions)):
        bar_statistic = bar_data["data"]
        if plot_box_plot:
            stat_array = [data[statistic] for data in bar_statistic]
            meanpointprops = dict(markeredgecolor='black', linewidth=0)
            capprops = dict(linewidth=2.5)
            print(stat_array)
            box_plt = plt.boxplot(stat_array, widths = barWidth,  positions=box_position, patch_artist=True, capprops=capprops, whiskerprops=capprops, boxprops=dict(facecolor=f"C{index}"), whis=(0,100), medianprops=meanpointprops) 
            box_plots.append(box_plt)
        if plot_maximum:
            stat_array = [np.max(data[statistic]) for data in bar_statistic]
            plt.bar(box_position, stat_array, width = barWidth, label = bar_data["label"]) 
        if plot_min_max_avg:
            first_time = True
            for (position, data) in zip(box_position, bar_statistic):
                solve_times = data[statistic]
                median_val = np.mean(solve_times)
                minimum = np.min(solve_times)
                maximum = np.max(solve_times)
                
                plt.errorbar(position, median_val, yerr=[[median_val - minimum], [maximum - median_val]],
                                fmt='h',  color=f"C{index}", ecolor=f"C{index}", capsize=10, ms=10, mew=2, elinewidth=3, label=bar_data["label"] if first_time  else '')
                first_time = False
    
    if not plot_maximum:
        plt.yticks(np.arange(0, ymax + 50, 50)) 
    else:
        plt.axhline(y=70, color='r', linestyle='-')
    
    FONT_SIZE_LABELS = 27

    #  Adding Xticks 
    plt.xlabel('World seed',labelpad=10, fontsize=FONT_SIZE_LABELS, fontweight='bold') 
    plt.ylabel(ylabel, labelpad=20, fontsize=FONT_SIZE_LABELS, fontweight='bold') 
    plt.xticks([r for r in range(len(seeds))], [f"{seed}" for seed in seeds])


    plt.xlim(-0.5, 4.5)
    
    # show separation lines between different seed groups
    for r in range(len(seeds) - 1):
        x_coord = r + 0.5
        plt.axvline(x = x_coord, color='white', linewidth=2,linestyle='--')
    
    if not plot_box_plot:
        plt.legend(
            loc='upper center', 
            bbox_to_anchor=(0.5, 1.23) if len(labels) > 4 else (0.5,1.15),
            ncol=2,
            frameon=False
        )
    else:
        plt.legend(
            [bp["boxes"][0] for bp in box_plots], 
            labels,         
            loc='upper center', 
            bbox_to_anchor=(0.5, 1.15),
            ncol=2,
            frameon=False
        )
    plt.subplots_adjust(top=top,bottom=bottom,left=left,right=right,hspace=hspace,wspace=wspace)
    plt.savefig('/home/nic/Documents/Uni/ResearchProject/plots/poster/poster.png', format='png', transparent=True, bbox_inches='tight')
    plt.show()

font = {
        'weight' : 'bold',
        'size'   : 22
}

matplotlib.rc('font', **font)
plt.style.use("dark_background")

seeds = GLOBAL_SEEDS_FOR_EXPERIMENTS

def plot_frangel_information():
    # frangel_data = create_bar_data_frangel(seeds, use_max_time = True)
    # plot_bar_data_array(frangel_data, seeds = seeds, plot_box_plot=False, plot_min_max_avg=True, ymax=200)

    # frangel_data = create_bar_data_frangel(seeds, use_fragement_prob=True)
    # plot_bar_data_array(frangel_data, seeds = seeds, plot_box_plot=False, plot_min_max_avg=True, ymax=200)

    frangel_data = create_bar_data_frangel(seeds, use_gen_similar_prob_new=True )
    plot_bar_data_array(frangel_data, seeds = seeds,  
        plot_box_plot=False,
        plot_min_max_avg=True, 
        ymax=200,
        barWidth=0.1,
        top=0.851,
        bottom=0.134,
        left=0.172,
        right=0.932,
        hspace=0.2,
        wspace=0.2
    )

    # frangel_data = create_bar_data_frangel(seeds, use_entire_fragment_chance=True)
    # plot_bar_data_array(frangel_data, seeds = seeds,  plot_box_plot=False, plot_min_max_avg=True, ymax=200)


def plot_probe_information():
    # plot data with cycle length
    # probe_data_cycles = create_probe_data(seeds, add_random=False)
    # plot_bar_data_array(probe_data_cycles, seeds = seeds,
    #     top=0.896,
    #     bottom=0.117,
    #     left=0.128,
    #     right=0.975,
    #     plot_box_plot=False,
    #     plot_maximum = True,
    #     statistic='best_reward',
    #     ylabel="Maximum achieved reward"
    # )

    # plot data with cycle length
    probe_data_random = create_probe_data(seeds, add_random=True)
    plot_bar_data_array(probe_data_random, seeds = seeds,
        top=0.896,
        bottom=0.117,
        left=0.128,
        right=0.975
    )

    # probe_data_all = create_probe_data(seeds, all_in_plot=True)
    # for dict_data in probe_data_all:
    #     print("Label", dict_data["label"])
    #     for (seed, seed_data) in zip(seeds, dict_data["data"]):
    #         solve_times = seed_data["solve_times"]
    #         print(f"Seed {seed} nr_solved = ", seed_data["nr_solved"])
    #         print(f"Seed {seed} avg = ", np.mean(solve_times))
    #         print(f"Seed {seed} stddev = ", np.std(solve_times))
    #     print("===")
        
# plot_probe_information()
plot_frangel_information()