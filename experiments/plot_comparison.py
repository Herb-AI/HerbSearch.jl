import os
import re
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter

def bar_chart(labels: list[str], regular_scores: list[int], aulile_scores: list[int]):
    x = range(len(labels))
    width = 0.35

    _, ax = plt.subplots(figsize=(10, 6))
    plt.bar([i - width/2 for i in x], regular_scores, width=width, label='Regular')
    plt.bar([i + width/2 for i in x], aulile_scores, width=width, label='Aulile')
    plt.xticks(x, labels)
    ax.yaxis.set_major_formatter(FuncFormatter(to_percent))

def line_chart(labels: list[str], regular_scores: list[int], aulile_scores: list[int]):
    x = range(len(labels))

    _, ax = plt.subplots(figsize=(10, 6))
    reg_line, = ax.plot(x, regular_scores, marker='s', ms=10, label='Regular', linestyle=':', color='red')
    reg_line.set_dashes([1, 3])
    aulile_line, = ax.plot(x, aulile_scores, marker='o', ms=10, label='Aulile', linestyle=':', color='blue')
    aulile_line.set_dashes([1, 4])
    plt.xticks(x, labels)
    ax.yaxis.set_major_formatter(FuncFormatter(to_percent))


def to_percent(y, position):
    return f"{100 * y:.0f}%"

def plot_experiment(experiments_folder: os.PathLike, 
                    save_dir: os.PathLike | None,
                    file_pattern=r"(\w+?)_(\d+)_(\d+)_(\d+)_.*\.txt"):
    pattern = re.compile(file_pattern)

    data = []
    benchmark_name = "Unknown benchmark"

    for filename in sorted(os.listdir(experiments_folder), reverse=True):
        match = pattern.match(filename)
        if match:
            benchmark_name = match.groups()[0]
            depth, iter, enum = map(int, match.groups()[1:])
            label = f"{enum}"

            filepath = os.path.join(experiments_folder, filename)

            # Load data (assuming one number per line)
            with open(filepath, "r") as f:
                lines = [line.strip() for line in f if line.strip()]
                reg, aulile = map(float, lines[-1].split(','))
                data.append((enum, label, reg, aulile))

    data.sort(key=lambda x: x[0])

    labels = [d[1] for d in data]
    regular_scores = [d[2] for d in data]
    aulile_scores = [d[3] for d in data]

    line_chart(labels, regular_scores, aulile_scores)

    plt.xlabel("Maximum Enumerations")
    plt.ylabel("Percent of Benchmark Problems solved")
    plt.title("Regular vs Aulile Scores for " + benchmark_name.capitalize() + " benchmark")
    plt.legend()
    plt.tight_layout()
    plt.grid(True, axis='y')

    if save_dir == None:
        plt.show()
    else:
        plt.savefig(save_dir)

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    plot_experiment(os.path.join(script_dir, "comparison_results"),
                    os.path.join(script_dir, "comparison_plot"))