import numpy as np 
import matplotlib.pyplot as plt 
import json 
import re

BOX_HEIGHT_WHEN_NOT_SOLVED = 5
EXPERIMENT_PATH = "src/minecraft/experiments"
PROBE_EXPERIMENT_PATH = f"{EXPERIMENT_PATH}/probe"
FRANGEL_EXPERIMENT_PATH = f"{EXPERIMENT_PATH}/frangel"

def compute_mean_of_attempt(attempt_list, key_total_time="total_time", key_solved="solved"):
    solved_attempts = [attempt[key_total_time] for attempt in attempt_list if attempt[key_solved]]
    if solved_attempts:
        return np.mean(solved_attempts)
    else:
        return BOX_HEIGHT_WHEN_NOT_SOLVED
    
def read_experiment_alternating_random(experiment_name, seeds):
    solved_time_data = []
    for seed_nr in seeds:
        with open(f"{PROBE_EXPERIMENT_PATH}/{experiment_name}/Seed_{seed_nr}.json","r") as f:
            json_data = json.load(f)
            run_data = json_data["data"]
            mean_solved_time = compute_mean_of_attempt(run_data)
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
                        mean_solved_time = compute_mean_of_attempt(value)
                        solved_time_data.append(mean_solved_time)
    return solved_time_data

def read_experiment_full_random():
    solved_time_data = []
    with open(f"{PROBE_EXPERIMENT_PATH}/experiment_pure_random/experiment.json","r") as f:
        json_data = json.load(f)
        for world in json_data:
            run_data = world["tries_data"]
            mean_solved_time = compute_mean_of_attempt(run_data)
            solved_time_data.append(mean_solved_time)
    return solved_time_data

def read_experiment_frangel_different_fragement_probs(seeds, fragement_prob):
    solved_time_data = []
    for seed in seeds: 
        with open(f"{FRANGEL_EXPERIMENT_PATH}/experiment_different_use_changes/Seed_{seed}.json","r") as f:
            json_data = json.load(f)
            run_data = json_data["tries_data"]
            
            fragement_prob_data = [attempt for attempt in run_data if attempt["frangel_config"]["generation"]["use_fragments_chance"] == fragement_prob]
            solved_time_data.append(compute_mean_of_attempt(fragement_prob_data, key_total_time="runtime"))
    return solved_time_data


def create_bar_data_frangel(seeds):
    bar_data_array = []
    for fragement_prob in [0.2, 0.4, 0.6, 0.8]:
        bar_data_array.append({
            "label": f"Frangel with $fragementprob = {fragement_prob}$",
            "data": read_experiment_frangel_different_fragement_probs(seeds, fragement_prob)
        })

    return bar_data_array

def create_bar_data_probe(seeds):
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

    # add random alternate data with p = 0.3
    bar_data_array.append({
        "label": "Random alternate with $p=0.3$",
        "data": read_experiment_alternating_random(experiment_name="experiment_alternating_random_0.3",seeds=seeds)
    })
    
    # add random alternate data with p = 0.5
    bar_data_array.append({
        "label": "Random alternate with $p=0.5$",
        "data": read_experiment_alternating_random(experiment_name="experiment_alternating_random_0.5",seeds=seeds)
    })
    
     # add random alternate data with p = 0.5
    bar_data_array.append({
        "label": "Random alternate with $p=1$",
        "data": read_experiment_alternating_random(experiment_name="experiment_alternating_random",seeds=seeds)
    })
    
    
    return bar_data_array

def plot_bar_data_array(bar_data_array, seeds, barWidth = 0.1, title="Average runtime with different probe configuration", **kwargs):
    bar_lengths = []
    for (i, cycle_data) in enumerate(bar_data_array):
        default_bar_spacing = np.arange(len(cycle_data["data"]))
        bar = [x + barWidth * i for x in default_bar_spacing]
        bar_lengths.append(bar)

    plt.subplots(figsize=(12, 8)) 
    for cycle_data, bar_length in zip(bar_data_array, bar_lengths):
        plt.bar(bar_length, cycle_data["data"], width = barWidth, label = cycle_data["label"]) 
    
    # # Adding Xticks 
    plt.xlabel('World seed', fontweight ='bold', fontsize = 15) 
    plt.ylabel('Average rutime for solving the NavigateTask', fontweight ='bold', fontsize = 15) 
    plt.xticks([r + barWidth * 2 for r in range(len(seeds))], [f"Seed {seed}" for seed in seeds])
    plt.title(title, fontsize = 20)
    
    plt.legend()
    plt.show() 

def show_probe():
    seeds = [1234, 4123, 4231, 9581, 9999] # Probe seeds 
    # seeds = [958129, 1234, 4123, 4231, 9999] # Frangel seeds
    bar_data = create_bar_data_probe(seeds)
    plot_bar_data_array(bar_data, seeds = seeds)

def show_frangel():
    seeds = [958129, 1234, 4123, 4231, 9999] # Frangel seeds
    bar_data = create_bar_data_frangel(seeds)
    plot_bar_data_array(bar_data, seeds = seeds)
show_frangel()