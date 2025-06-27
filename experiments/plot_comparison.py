import os
import re
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
from collections import defaultdict
from typing import Optional, List, Pattern
import random
import colorsys


def bar_chart(
    labels: list[str], regular_scores: list[float], aulile_scores: list[float]
):
    x = range(len(labels))
    width = 0.35

    _, ax = plt.subplots(figsize=(10, 6))
    plt.bar([i - width / 2 for i in x], regular_scores, width=width, label="Regular")
    plt.bar([i + width / 2 for i in x], aulile_scores, width=width, label="Aulile")
    plt.xticks(x, labels)
    ax.yaxis.set_major_formatter(FuncFormatter(to_percent))


def get_random_bluish_color(mode: str, seed_base=42):
    random.seed(seed_base)  # ensure consistent color -> may add mode
    # Hue near blue (~0.55–0.65), full saturation, high value for visibility
    hue = random.uniform(0.48, 0.57)
    saturation = random.uniform(0.7, 1.0)
    value = random.uniform(0.7, 1.0)
    r, g, b = colorsys.hsv_to_rgb(hue, saturation, value)
    return (r, g, b)  # matplotlib accepts RGB tuples in 0–1 range


def line_chart(labels: list[str], mode_scores: dict[str, list[float]]):
    x = range(len(labels))
    _, ax = plt.subplots(figsize=(10, 6))

    non_regular_modes = {k: v for k, v in mode_scores.items() if k != "regular"}
    best_mode = max(non_regular_modes.items(), key=lambda kv: kv[1][-1])[0]

    for mode, scores in mode_scores.items():
        if mode == "regular":
            style = {"marker": "s", "color": "red", "dash": [1, 3], "ms":13, "alpha":0.6}
        else:

            style = {"marker": "o", "color": get_random_bluish_color(mode), "dash": [1, 6],
                     "ms":8, "alpha":0.8}
        
        # Highlight best non-regular mode
        if mode == best_mode:
            assert mode != "regular"
            style["color"] = "blue"    # Special highlight color
            style["marker"] = "D"      # Diamond marker
            style["dash"] = [1, 4]
            style["ms"] = 13
            style["alpha"] = 0.8

        (line,) = ax.plot(
            x,
            scores,
            marker=style["marker"],
            label=mode.capitalize(),
            ms=style["ms"],
            alpha=style["alpha"],
            linestyle=":",
            color=style["color"],
        )
        line.set_dashes(style["dash"])

    plt.xticks(x, labels)
    ax.yaxis.set_major_formatter(FuncFormatter(to_percent))


def to_percent(y, _):
    return f"{100 * y:.0f}%"


def plot_experiment(
    experiments_folder: os.PathLike,
    save_dir: os.PathLike | None,
    file_patterns: List[Pattern] = [re.compile(r"(\w+?)_(\d+)_(\d+)_(\d+)_.*\.txt")],
):
    # Structure: {(benchmark, depth, iters, enum): {mode: score}}
    grouped_data = defaultdict(lambda: {})

    for filename in sorted(os.listdir(experiments_folder), reverse=True):
        for pattern in file_patterns:
            match = pattern.match(filename)
            if not match:
                continue

            benchmark, depth, iters, enum = match.groups()
                
            depth, iters, enum = map(int, (depth, iters, enum))
            label = f"{enum}"
            filepath = os.path.join(experiments_folder, filename)

            modes = None
            percentages = None
            with open(filepath, "r") as f:
                lines = [line.strip() for line in f if line.strip()]
                modes = [f.lower() for f in lines[-2].split(",")]
                percentages = [float(p) for p in lines[-1].split(",")]
                assert len(modes) == len(percentages)

            key = (benchmark, depth, iters, enum)
            for i, mode in enumerate(modes):
                grouped_data[key][mode] = percentages[i]

    # Reorganize the grouped data: group by (benchmark, depth, iters)
    merged_data = defaultdict(list)
    for (benchmark, depth, iters, enum), scores_by_mode in grouped_data.items():
        merged_data[(benchmark, depth, iters)].append((enum, scores_by_mode))

    for (benchmark, depth, iters), data_points in merged_data.items():
        data_points.sort(key=lambda x: x[0])  # sort by enum

        labels = [str(enum) for enum, _ in data_points]
        
        # Collect scores per mode
        all_modes = set()
        for _, scores in data_points:
            all_modes.update(scores.keys())

        # Sort modes for consistent ordering
        all_modes = sorted(all_modes)
        
        mode_scores = {mode: [] for mode in all_modes}
        for _, scores in data_points:
            for mode in all_modes:
                mode_scores[mode].append(scores.get(mode, 0.0))  # default to 0.0 if missing

        enum_range = f"{data_points[0][0]}–{data_points[-1][0]}"

        line_chart(labels, mode_scores)

        plt.xlabel("Maximum Enumerations")
        plt.ylabel("Percent of Benchmark Problems Solved")
        plt.title(
            f"{benchmark.capitalize()} (Depth={depth}, Iter={iters}, Enums={enum_range})"
        )
        plt.legend()
        plt.tight_layout()
        plt.grid(True, axis="y")

        if save_dir is None:
            plt.show()
        else:
            os.makedirs(save_dir, exist_ok=True)
            out_path = os.path.join(save_dir, f"{benchmark}_d{depth}_i{iters}.png")
            plt.savefig(out_path)

        plt.close()


if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    plot_experiment(
        os.path.join(script_dir, "results"),
        os.path.join(script_dir, "comparison_plots"),
    )
