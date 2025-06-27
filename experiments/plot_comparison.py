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


def line_chart(
    labels: list[str], mode_scores: dict[str, list[float]], benchmark_name: str
):
    x = range(len(labels))
    _, ax = plt.subplots(figsize=(10, 6))

    non_regular_modes = {k: v for k, v in mode_scores.items() if k != "regular"}
    best_mode = max(non_regular_modes.items(), key=lambda kv: kv[1][-1])[0]

    baseline_color = (1.0, 0.0, 0.0)  # red
    best_color = (0.0, 0.0, 1.0)  # blue
    regular_final = mode_scores["regular"][-1]
    best_final = mode_scores[best_mode][-1]

    CUSTOM_LABELS = {
        "strings": {
            "regular": "Regular",
            "aulile_edit_distance": "Aulile_edit_distance",
            "aulile_penalize_deleting": "Aulile_case-sensitive_distance (D=1, I=inf, S=inf)",
            "aulile_penalize_deleting2": "Aulile_case-sensitive_distance (D=Inf, I=1, S=1)",
        }
    }

    variant_modes = [m for m in non_regular_modes if m != best_mode]
    n_variants = len(variant_modes)
    variant_colors = [
        colorsys.hsv_to_rgb(0.6, 0.6, 0.5 + 0.5 * i / max(1, n_variants - 1))
        for i in range(n_variants)
    ]
    variant_color_map = dict(zip(variant_modes, variant_colors))

    for mode, scores in mode_scores.items():
        if mode == "regular":
            style = {
                "marker": "s",
                "color": baseline_color,
                "dash": [1, 3],
                "ms": 13,
                "alpha": 0.6,
            }
        elif mode == best_mode:
            style = {
                "marker": "D",
                "color": best_color,
                "dash": [1, 4],
                "ms": 13,
                "alpha": 0.8,
            }
        else:
            style = {
                "marker": "o",
                "color": variant_color_map[mode],
                "dash": [1, 6],
                "ms": 8,
                "alpha": 0.8,
            }

        (line,) = ax.plot(
            x,
            scores,
            marker=style["marker"],
            label=CUSTOM_LABELS.get(benchmark_name, {}).get(mode, mode.capitalize()),
            ms=style["ms"],
            alpha=style["alpha"],
            linestyle=":",
            color=style["color"],
        )
        line.set_dashes(style["dash"])

    plt.xticks(x, labels, fontsize=14, rotation=30)
    plt.yticks(fontsize=14, rotation=30)
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
                mode_scores[mode].append(
                    scores.get(mode, 0.0)
                )  # default to 0.0 if missing

        enum_range = f"{data_points[0][0]}–{data_points[-1][0]}"

        line_chart(labels, mode_scores, benchmark)

        plt.xlabel("Number of maximum allowed evaluations", fontsize=14)
        plt.ylabel("Percent of Benchmark Problems Solved", fontsize=14)
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
        os.path.join(script_dir, "comparison_results"),
        os.path.join(script_dir, "comparison_plots"),
    )
