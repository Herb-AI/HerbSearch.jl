import numpy as np 
import matplotlib.pyplot as plt 
import json 
import re

GLOBAL_SEEDS_FOR_EXPERIMENTS = [1234, 4123, 4231, 9581, 9999] # taken from experiment_helpers.jl
BOX_HEIGHT_WHEN_NOT_SOLVED = 5
EXPERIMENT_PATH = "src/minecraft/experiments"
PROBE_EXPERIMENT_PATH = f"{EXPERIMENT_PATH}/probe"
FRANGEL_EXPERIMENT_PATH = f"{EXPERIMENT_PATH}/frangel"

def compute_statistics_of_attempt(attempt_list, key_total_time="total_time", key_solved="solved", key_reward_over_time="best_reward_over_time"):
    solved_attempts_runtime = [attempt[key_total_time] for attempt in attempt_list if attempt[key_solved]]
    # asume (time, reward)
    best_reward = [max(attempt[key_reward_over_time], key=lambda x: x[1])[1] for attempt in attempt_list ]

    mean_solve_time = BOX_HEIGHT_WHEN_NOT_SOLVED
    std_solve_time = 0
    if solved_attempts_runtime:
        mean_solve_time = np.mean(solved_attempts_runtime)
        std_solve_time = np.std(solved_attempts_runtime)
    
    return {
        "mean_solve_time": mean_solve_time,
        "std_solve_time": std_solve_time,
        "mean_best_reward": np.mean(best_reward),
        "max_reward": np.max(best_reward),
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
        with open(f"{PROBE_EXPERIMENT_PATH}/experiment_cycles/Seed_{seed_nr}.json","r") as f:
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
            solved_time_data.append(compute_statistics_of_attempt(fragement_prob_data, key_total_time="runtime", key_reward_over_time='reward_over_time'))
    return solved_time_data


def create_bar_data_frangel(seeds):
    bar_data_array = []
    for fragement_prob in [0.2, 0.4, 0.6, 0.8]:
        filter_lambda = lambda attempt: attempt["frangel_config"]["generation"]["use_fragments_chance"] == fragement_prob
        bar_data_array.append({
            "label": f"Frangel with $fragementprob = {fragement_prob}$",
            "data": read_experiment_frangel_filtering_for(seeds, experiment_name="experiment_different_use_fragement_probabilities", filter_lambda=filter_lambda)
        })
    for max_time in [5, 10, 20, 30]:
        filter_lambda = lambda attempt: attempt["frangel_config"]["max_time"] == max_time
        bar_data_array.append({
            "label": f"Frangel with $max_time = {max_time}$",
            "data": read_experiment_frangel_filtering_for(seeds, experiment_name="experiment_different_frangel_max_time", filter_lambda=filter_lambda)
        })

    return bar_data_array

def create_bar_data_probe(seeds, add_random = True):
    bar_data_array = []

    # add bars for cycle lengths
    for i in range(5,9):
        bar_data_array.append({
            "label": f"Cycle {i}",
            "data": read_experiment_cycles(seeds, i)
        })
        
    # # add full random data
    # bar_data_array.append({
    #     "label": "Full random",
    #     "data": read_experiment_full_random()
    # })
    if add_random:
        probabilities = [0.3, 0.5, 1]
        for prob in probabilities:
            bar_data_array.append({
                "label": f"Random alternate with $p={prob}$",
                "data": read_experiment_alternating_random(experiment_name=f"experiment_alternating_random_{prob}",seeds=seeds)
            })
    return bar_data_array

def plot_bar_data_array(bar_data_array, seeds, barWidth = 0.1, statistic = 'mean_solve_time', title=None, ylabel='Average rutime for solving the NavigateTask', **kwargs):
    if not title :
        title = f"Statistic {statistic} with different configurations"
    
    bar_lengths = []
    for (i, bar_data) in enumerate(bar_data_array):
        default_bar_spacing = np.arange(len(bar_data["data"]))
        bar = [x + barWidth * i for x in default_bar_spacing]
        bar_lengths.append(bar)

    plt.subplots(figsize=(12, 8)) 
    for bar_data, bar_length in zip(bar_data_array, bar_lengths):
        bar_statistic = [element[statistic] for element in bar_data["data"]]
        plt.bar(bar_length, bar_statistic, width = barWidth, label = bar_data["label"]) 
    
    # # Adding Xticks 
    plt.xlabel('World seed', fontweight ='bold', fontsize = 15) 
    plt.ylabel(ylabel, fontweight ='bold', fontsize = 15) 
    plt.xticks([r + barWidth * 2 for r in range(len(seeds))], [f"Seed {seed}" for seed in seeds])
    plt.title(title, fontsize = 20)
    
    plt.legend()
    plt.show() 

seeds = GLOBAL_SEEDS_FOR_EXPERIMENTS 
bar_data_probe = create_bar_data_probe(seeds, add_random=True)
bar_data_frangel = create_bar_data_frangel(seeds)

plot_bar_data_array(bar_data_frangel, seeds = seeds, statistic='mean_solve_time')
plot_bar_data_array(bar_data_frangel, seeds = seeds, statistic='std_solve_time')
