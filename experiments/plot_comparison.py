import os
import re
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
from collections import defaultdict


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
    labels: list[str], regular_scores: list[float], aulile_scores: list[float]
):
    x = range(len(labels))

    _, ax = plt.subplots(figsize=(10, 6))
    (reg_line,) = ax.plot(
        x,
        regular_scores,
        marker="s",
        ms=10,
        label="Regular",
        linestyle=":",
        color="red",
    )
    reg_line.set_dashes([1, 3])
    (aulile_line,) = ax.plot(
        x, aulile_scores, marker="o", ms=10, label="Aulile", linestyle=":", color="blue"
    )
    aulile_line.set_dashes([1, 4])
    plt.xticks(x, labels)
    ax.yaxis.set_major_formatter(FuncFormatter(to_percent))


def to_percent(y, _):
    return f"{100 * y:.0f}%"


def plot_experiment(
    experiments_folder: os.PathLike,
    save_dir: os.PathLike | None,
    file_pattern=r"(\w+?)_(\d+)_(\d+)_(\d+)_.*\.txt",
):
    pattern = re.compile(file_pattern)
    grouped_data = defaultdict(list)

    for filename in sorted(os.listdir(experiments_folder), reverse=True):
        match = pattern.match(filename)
        if not match:
            continue

        benchmark, depth, iters, enum = match.groups()
        depth, iters, enum = map(int, (depth, iters, enum))
        label = f"{enum}"
        filepath = os.path.join(experiments_folder, filename)

        reg_solved = 0
        aulile_solved = 0
        total_problems = 0

        with open(filepath, "r") as f:
            for line in f:
                line = line.strip()
                if not line or ";" not in line or "Reg_iter" in line:
                    continue
                reg_part, aulile_part = line.split(";")
                reg_part = reg_part.split(":")[1].strip()
                reg_flag = int(reg_part.strip().split(",")[0])
                aulile_flag = int(aulile_part.strip().split(",")[0])
                reg_solved += reg_flag
                aulile_solved += aulile_flag
                total_problems += 1

        if total_problems == 0:
            continue

        reg_score = reg_solved / total_problems
        aulile_score = aulile_solved / total_problems
        key = (benchmark, depth, iters)
        grouped_data[key].append((enum, label, reg_score, aulile_score))

    for (benchmark, depth, iters), data_points in grouped_data.items():
        data_points.sort(key=lambda x: x[0])  # sort by enum

        labels = [x[1] for x in data_points]
        reg_scores = [x[2] for x in data_points]
        aulile_scores = [x[3] for x in data_points]
        enum_range = f"{data_points[0][0]}–{data_points[-1][0]}"

        line_chart(labels, reg_scores, aulile_scores)

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
        os.path.join(script_dir, "comparison_results"),
        os.path.join(script_dir, "comparison_plots"),
    )
