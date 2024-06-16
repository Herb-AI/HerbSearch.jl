import json
import matplotlib.pyplot as plt
import os
import numpy as np
from collections import defaultdict
from scipy.interpolate import interp1d

# Helper function for interpolating data
def interpolate_and_average(arrays, num_points=100):
    """
    Interpolate each array to a common set of x-values and then average them.

    :param arrays: List of arrays to be interpolated and averaged.
    :param num_points: Number of points to interpolate to.
    :return: Averaged array.
    """
    # Define the common x-values for interpolation
    common_x = np.linspace(0, 1, num_points)

    # Interpolate each array to the common x-values
    interpolated_arrays = []
    for array in arrays:
        original_x = np.linspace(0, 1, len(array))
        interp_func = interp1d(original_x, array, kind='linear', fill_value="extrapolate")
        interpolated_array = interp_func(common_x)
        interpolated_arrays.append(interpolated_array)

    # Average the interpolated arrays
    averaged_array = np.mean(interpolated_arrays, axis=0)
    
    return common_x, averaged_array

# Function to determine plot color based on maximum value
def determine_plot_color(max_value, min_val=0, max_val=100):
    """
    Determine color based on the maximum value.
    Green for high values, red for low values.

    :param max_value: The maximum value in the data array.
    :param min_val: The minimum value for scaling (default 0).
    :param max_val: The maximum value for scaling (default 100).
    :return: Color in hex format.
    """
    ratio = (max_value - min_val) / (max_val - min_val)
    # Clamp ratio to [0, 1]
    ratio = max(0, min(1, ratio))
    # Apply non-linear scaling (quadratic)
    ratio = ratio ** 2
    # Green (0, 1, 0) to Red (1, 0, 0) gradient
    red = 1 - ratio
    green = ratio
    return (red, green, 0), ('--' if green < 0.33 else '-')

# Function to nestedly access an object, dynamically
def get_nested_values(data, keys):
    vals = []
    root = data
    for key in keys:
        data = root
        subkeys = key.split('/')
        for subkey in subkeys:
            if subkey in data:
                data = data[subkey]
            else:
                raise KeyError(f"Key '{subkey}' not found in data")
        vals.append(data)
    return vals

# Function helper for loading data from JSONs
def load_data(base_exp_dir, seed, config_vars, include_last):
    config_vars_names = list(map(lambda x: x.split('/')[-1], config_vars))
    print(config_vars_names)
    # Get all JSON files in the directory
    _, _, files = next(os.walk(base_exp_dir))
    file_count = len(files)
    # List of JSON filenames
    filenames = [f'{base_exp_dir}/Seed_{seed}.json'] + \
        [f'{base_exp_dir}/Seed_{seed}_{i}.json' for i in range(2, file_count + (1 if include_last else 0))]

    # Data aggregation structures
    config_data_program = defaultdict(list)
    config_data_fragment = defaultdict(list)
    average_runtime = defaultdict(list)
    average_program_complexities = defaultdict(int)

    # Load and aggregate data
    for filename in filenames:
        with open(filename, 'r') as file:
            data = json.load(file)

        for try_data in data["tries_data"]:
            runtime = try_data["runtime"]
            vars = get_nested_values(try_data["frangel_config"], config_vars)
            config_key = tuple(vars)
            
            program_complexity = try_data["program_complexity_over_time"]
            fragment_complexity = try_data["fragment_complexity_over_time"]
            
            average_runtime[config_key].append(runtime)
            config_data_program[config_key].append(program_complexity)
            config_data_fragment[config_key].append(fragment_complexity)

    # Process each configuration for programs
    for config_key, program_arrays in config_data_program.items():
        print(f'Number of tries for config {config_key}:{len(program_arrays)}')
        # Interpolate and average program complexity data
        _, averaged_program = interpolate_and_average(program_arrays)
        average_program_complexities[config_key] = np.mean(averaged_program)

    return config_data_fragment, average_runtime, average_program_complexities, config_vars_names


# Function for analyzing data and generating plots
def analyze_data(base_exp_dir, seed, output_loc, paper_configs, legend_order, minmax_color, config_vars, include_last=True, plot_mean=False):
    # Create plots directory if it doesn't exist
    os.makedirs(output_loc, exist_ok=True)
    # Load data
    config_data_fragment, average_runtime, average_program_complexities, config_vars_names = load_data(base_exp_dir, seed, config_vars, include_last)
    print('\n')

    ################################
    ##### FIGURE FOR ANALYSIS ######
    ################################

    # Plot fragment complexity data for all configurations
    plt.figure(figsize=(42, 24))
    # Process each configuration for fragments
    for config_key, fragment_arrays in config_data_fragment.items():
        # Interpolate and average fragment complexity data
        common_x_program, averaged_program = interpolate_and_average(fragment_arrays)
        # Plot graph
        flattened_config_str = ', '.join([f"{k} = {v}" for k, v in zip(config_vars_names, config_key)])
        plt.plot(common_x_program, averaged_program, label=f'({flattened_config_str}), runtime={np.mean(average_runtime[config_key]):.2f}, avg_program_complexity={average_program_complexities[config_key]:.2f}')

    # Prepare rest of plot
    plt.xlabel('Normalized Time')
    plt.ylabel('Fragment Complexity (average #nodes / fragment)')
    plt.title(f'Plot of Fragment Complexity over-time for ({", ".join([f"`{k}`" for k in config_vars_names])}) combinations, world_seed {seed}')
    plt.legend()
    plt.grid(True)
    plt.savefig(f'{output_loc}/fragment_complexity_over_time_full_{seed}.png')
    plt.close()

    ################################
    ####### FIGURE FOR PAPER #######
    ################################

    for (i, pc) in enumerate(paper_configs):
        all_averages = []
        # Plot fragment complexity data for some configurations only
        plt.figure(figsize=(16, 8))
        for conf in pc:
            # Interpolate and average fragment complexity data
            common_x_program, averaged_program = interpolate_and_average(config_data_fragment[conf])
            # Add to total averages for mean of all configs
            all_averages.append(averaged_program)
            # Determine what color and plot style to use for config
            avg_color, plot_style = determine_plot_color(np.mean(averaged_program), minmax_color[0], minmax_color[1])
            # Plot graph
            flattened_config_str = ', '.join([f"{k} = {v}" for k, v in zip(config_vars_names, conf)])
            plt.plot(common_x_program, averaged_program, plot_style, color=avg_color, 
                label=f'({flattened_config_str}), runtime={np.mean(average_runtime[conf]):.2f}, avg_program_complexity={average_program_complexities[conf]:.2f}')
        
        # Prepare rest of plot
        if len(pc) > 0:

            if plot_mean:
                # Plot average across all configurations
                common_x_program, averaged_program = interpolate_and_average(all_averages)
                plt.plot(common_x_program, averaged_program, color='pink', label='Average fragment complexity over all configurations', linewidth=4.0)

            plt.xlabel('Normalized Time')
            plt.ylabel('Fragment Complexity (average #nodes / fragment)')
            plt.title(f'Plot of Fragment Complexity over-time for ({", ".join([f"`{k}`" for k in config_vars_names])}) combinations, world_seed {seed}')
            plt.legend()

            plt.legend(*(
                [ x[i] for i in legend_order[:len(pc)] ]
                for x in plt.gca().get_legend_handles_labels()
            ), handletextpad=0.75, loc='best')

            plt.grid(True)
            plt.savefig(f'{output_loc}/fragment_complexity_over_time_{seed}{("" if i == 0 else f"_{i + 1}")}.png')
            plt.close()

# Function for summarizing data with bar charts
def summarize_data(config_vars, possible_vals, base_exp_dir, seed, output_loc):
    # Create plots directory if it doesn't exist
    os.makedirs(output_loc, exist_ok=True)
    config_data_fragment, _, average_program_complexities, config_vars_names = load_data(base_exp_dir, seed, config_vars, True)
    print('\n')

    bar_data = []
    bar_program_data = []
    bar_labels = []
    for (i, _) in enumerate(config_vars):
        for config_val in possible_vals[i]:
            arrays = []
            # Add fragments
            for fragment_key, fragment_data in config_data_fragment.items():
                if fragment_key[i] == config_val:
                    for arr in fragment_data:
                        arrays.append(np.mean(arr))
            bar_data.append(arrays)
            bar_labels.append(config_val)
            # Add programs
            for program_key, program_data in average_program_complexities.items():
                if program_key[i] == config_val:
                    bar_program_data.append(program_data)

    barWidth = 0.05

    # Positions
    bar_positions = []
    for (i, _) in enumerate(config_vars):
        l = len(possible_vals[i])
        for j in range(l):
            bar_positions.append((i + 1) + j * barWidth * 2 - (barWidth if l % 2 == 0 else 0))

    # Plot boxes
    plt.subplots(figsize=(12, 8)) 
    plt.boxplot(bar_data, positions=bar_positions, widths = barWidth) 

    # Annotate
    for i in range(len(bar_data)):
        plt.annotate(bar_labels[i], (bar_positions[i], 2.115), ha='center')

        # Determine location of upper whisker
        q1 = np.percentile(bar_data[i], 25)
        q3 = np.percentile(bar_data[i], 75)
        iqr = q3 - q1
        upper_whisker_limit = q3 + 1.5 * iqr
        upper_whisker = np.max([x for x in bar_data[i] if x <= upper_whisker_limit])

        plt.annotate(str(round(np.mean(bar_program_data[i]), 2)), (bar_positions[i], upper_whisker + 0.01), ha='center')
    
    plt.xlabel('Feature that is aggregated on', fontsize = 15) 
    plt.ylabel('Fragment Complexity (average #nodes / fragment)', fontsize = 15) 
    plt.xticks([(r + 1) + barWidth * 2 for r in range(len(config_vars_names))], config_vars_names)
    plt.title(f"Summary of how config features affect fragment and program complexity, seed {seed}", fontsize = 15)
    
    plt.legend()
    plt.grid(True)
    plt.savefig(f'{output_loc}/fragment_complexity_over_time_{seed}_summary.png')
    plt.close()