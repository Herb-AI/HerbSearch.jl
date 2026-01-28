#!/usr/bin/env python3
"""
Analysis script for HerbSearch experiment results.

Usage:
    python analyze_results.py <results_directory> [output_directory]

Example:
    python analyze_results.py ../data/experimentcommon3 ./plots
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import glob
import os
import sys
from pathlib import Path


def extract_problem_name(filename, search_type):
    """Extract problem name from filename, handling various patterns."""
    import re

    basename = os.path.basename(filename)
    # Handle patterns like: problem_name_control_d5_s5.csv or problem_name_budgeted_d5_s5.csv
    pattern = rf"(.+?)_{search_type}_d\d+_s\d+\.csv"
    match = re.match(pattern, basename)
    if match:
        return match.group(1)
    # Fallback to old patterns
    return basename.replace(f"_{search_type}_sizebased.csv", "").replace(
        f"_{search_type}.csv", ""
    )


def load_csv_files(results_dir, require_both=True):
    """Load and separate CSV files into control and budgeted DataFrames.

    Args:
        results_dir: Directory containing CSV files
        require_both: If True, only include problems that have both control and budgeted files
    """

    control_files = glob.glob(os.path.join(results_dir, "*_control*.csv"))
    budgeted_files = glob.glob(os.path.join(results_dir, "*_budgeted*.csv"))

    print(f"Found {len(control_files)} control files")
    print(f"Found {len(budgeted_files)} budgeted files")

    # Build mapping of problem name to file
    control_by_problem = {}
    for f in control_files:
        problem_name = extract_problem_name(f, "control")
        control_by_problem[problem_name] = f

    budgeted_by_problem = {}
    for f in budgeted_files:
        problem_name = extract_problem_name(f, "budgeted")
        budgeted_by_problem[problem_name] = f

    # Find problems with both if required
    if require_both:
        common_problems = set(control_by_problem.keys()) & set(
            budgeted_by_problem.keys()
        )
        excluded_control = set(control_by_problem.keys()) - common_problems
        excluded_budgeted = set(budgeted_by_problem.keys()) - common_problems

        if excluded_control:
            print(
                f"Excluding {len(excluded_control)} control-only problems: {sorted(excluded_control)[:5]}{'...' if len(excluded_control) > 5 else ''}"
            )
        if excluded_budgeted:
            print(
                f"Excluding {len(excluded_budgeted)} budgeted-only problems: {sorted(excluded_budgeted)[:5]}{'...' if len(excluded_budgeted) > 5 else ''}"
            )
        print(
            f"Including {len(common_problems)} problems with both control and budgeted runs"
        )
    else:
        common_problems = set(control_by_problem.keys()) | set(
            budgeted_by_problem.keys()
        )

    control_dfs = []
    for problem_name in common_problems:
        if problem_name not in control_by_problem:
            continue
        f = control_by_problem[problem_name]
        try:
            df = pd.read_csv(f)
            basename = os.path.basename(f)
            df["problem_name"] = problem_name
            df["source_file"] = basename
            control_dfs.append(df)
        except Exception as e:
            print(f"Error loading {f}: {e}")

    budgeted_dfs = []
    for problem_name in common_problems:
        if problem_name not in budgeted_by_problem:
            continue
        f = budgeted_by_problem[problem_name]
        try:
            df = pd.read_csv(f)
            basename = os.path.basename(f)
            df["problem_name"] = problem_name
            df["source_file"] = basename
            budgeted_dfs.append(df)
        except Exception as e:
            print(f"Error loading {f}: {e}")

    control_df = (
        pd.concat(control_dfs, ignore_index=True) if control_dfs else pd.DataFrame()
    )
    budgeted_df = (
        pd.concat(budgeted_dfs, ignore_index=True) if budgeted_dfs else pd.DataFrame()
    )

    return control_df, budgeted_df, len(control_dfs), len(budgeted_dfs)


def get_final_scores(df, is_budgeted=False):
    """Extract final best scores for each problem.

    For control: summary row has attempt=-1
    For budgeted: summary row has "Final result so no updates" in new_updated_rules column
    """
    if df.empty:
        return pd.DataFrame()

    final_scores = []
    for problem_name in df["problem_name"].unique():
        problem_df = df[df["problem_name"] == problem_name]

        if is_budgeted:
            # For budgeted: find row with "Final result so no updates" in new_updated_rules
            if "new_updated_rules" in problem_df.columns:
                summary_row = problem_df[
                    problem_df["new_updated_rules"].str.contains(
                        "Final result", na=False
                    )
                ]
                if summary_row.empty:
                    # Fallback: use third-last row (before grammar and timeout rows)
                    if len(problem_df) >= 3:
                        summary_row = problem_df.iloc[[-3]]
            else:
                summary_row = pd.DataFrame()
        else:
            # For control: summary row has attempt=-1
            summary_row = problem_df[problem_df["attempt"] == -1]

        if not summary_row.empty:
            final_scores.append(
                {
                    "problem_name": problem_name,
                    "final_score": summary_row.iloc[0]["program_score"],
                }
            )

    return pd.DataFrame(final_scores)


def get_timeout_info(df):
    """Extract timeout information from attempt=-2 rows."""
    if df.empty:
        return pd.DataFrame()

    timeout_info = []
    for problem_name in df["problem_name"].unique():
        problem_df = df[df["problem_name"] == problem_name]

        # Get timeout row (attempt = -2)
        timeout_row = problem_df[problem_df["attempt"] == -2]
        if not timeout_row.empty:
            best_program = str(timeout_row.iloc[0]["best_program"])
            timed_out = "true" in best_program.lower()
            timeout_info.append({"problem_name": problem_name, "timed_out": timed_out})

    return pd.DataFrame(timeout_info)


def get_total_runtime(df, is_budgeted=False):
    """Extract total runtime for each problem.

    For control: summary row has attempt=-1 with total time in time_seconds
    For budgeted: summary row has "Final result so no updates" with total time in time column
    """
    if df.empty:
        return pd.DataFrame()

    runtimes = []
    for problem_name in df["problem_name"].unique():
        problem_df = df[df["problem_name"] == problem_name]

        if is_budgeted:
            # For budgeted: find row with "Final result so no updates" in new_updated_rules
            if "new_updated_rules" in problem_df.columns:
                summary_row = problem_df[
                    problem_df["new_updated_rules"].str.contains(
                        "Final result", na=False
                    )
                ]
                if summary_row.empty:
                    # Fallback: use third-last row (before grammar and timeout rows)
                    if len(problem_df) >= 3:
                        summary_row = problem_df.iloc[[-3]]
            else:
                summary_row = pd.DataFrame()
            if not summary_row.empty:
                runtime = summary_row.iloc[0].get("time", 0)
                runtimes.append({"problem_name": problem_name, "runtime": runtime})
        else:
            # For control: summary row has attempt=-1
            summary_row = problem_df[problem_df["attempt"] == -1]
            if not summary_row.empty:
                runtime = summary_row.iloc[0].get("time_seconds", 0)
                runtimes.append({"problem_name": problem_name, "runtime": runtime})

    return pd.DataFrame(runtimes)


def analysis_1_score_distribution(control_df, budgeted_df, output_dir):
    """
    Analysis 1: Scatter plot of scores vs number of benchmarks that achieved that score.
    Two series: one for control, one for budgeted.
    """

    control_final = get_final_scores(control_df, is_budgeted=False)
    budgeted_final = get_final_scores(budgeted_df, is_budgeted=True)

    if control_final.empty and budgeted_final.empty:
        print("No data for Analysis 1")
        return

    # Create score bins (0.0, 0.1, 0.2, ..., 1.0)
    score_bins = np.arange(0, 1.1, 0.1)

    fig, ax = plt.subplots(figsize=(10, 6))

    if not control_final.empty:
        control_counts, _ = np.histogram(control_final["final_score"], bins=score_bins)
        bin_centers = (score_bins[:-1] + score_bins[1:]) / 2
        ax.scatter(
            bin_centers,
            control_counts,
            color="blue",
            label="Control",
            s=100,
            marker="o",
            zorder=3,
        )

    if not budgeted_final.empty:
        budgeted_counts, _ = np.histogram(
            budgeted_final["final_score"], bins=score_bins
        )
        bin_centers = (score_bins[:-1] + score_bins[1:]) / 2
        ax.scatter(
            bin_centers,
            budgeted_counts,
            color="orange",
            label="Budgeted Search",
            s=100,
            marker="s",
            zorder=3,
        )

    ax.set_xlabel("Final Score", fontsize=12)
    ax.set_ylabel("Number of Benchmarks", fontsize=12)
    ax.set_title("Score Distribution: Control vs Budgeted Search", fontsize=14)
    ax.legend(fontsize=11)
    ax.grid(True, alpha=0.3)
    ax.set_xlim(-0.05, 1.05)
    ax.set_xticks(np.arange(0, 1.1, 0.1))

    plt.tight_layout()
    output_path = os.path.join(output_dir, "analysis1_score_distribution.png")
    plt.savefig(output_path, dpi=150)
    print(f"Saved: {output_path}")
    plt.close()


def analysis_2_cumulative_best_by_attempt(control_df, budgeted_df, output_dir):
    """
    Analysis 2: Scatter plot of attempt number vs cumulative best score found,
    averaged across all benchmarks. Two series: control and budgeted.
    """

    if control_df.empty and budgeted_df.empty:
        print("No data for Analysis 2")
        return

    fig, ax = plt.subplots(figsize=(10, 6))

    # Process control data
    if not control_df.empty:
        control_cumulative = compute_cumulative_best_per_attempt(control_df)
        if not control_cumulative.empty:
            ax.scatter(
                control_cumulative["attempt"],
                control_cumulative["avg_cumulative_best"],
                color="blue",
                label="Control",
                s=80,
                marker="o",
                zorder=3,
            )
            # Add error bars for std dev
            ax.errorbar(
                control_cumulative["attempt"],
                control_cumulative["avg_cumulative_best"],
                yerr=control_cumulative["std_cumulative_best"],
                fmt="none",
                color="blue",
                alpha=0.3,
                capsize=3,
            )

    # Process budgeted data
    if not budgeted_df.empty:
        budgeted_cumulative = compute_cumulative_best_per_attempt(budgeted_df)
        if not budgeted_cumulative.empty:
            ax.scatter(
                budgeted_cumulative["attempt"],
                budgeted_cumulative["avg_cumulative_best"],
                color="orange",
                label="Budgeted Search",
                s=80,
                marker="s",
                zorder=3,
            )
            ax.errorbar(
                budgeted_cumulative["attempt"],
                budgeted_cumulative["avg_cumulative_best"],
                yerr=budgeted_cumulative["std_cumulative_best"],
                fmt="none",
                color="orange",
                alpha=0.3,
                capsize=3,
            )

    ax.set_xlabel("Attempt Number", fontsize=12)
    ax.set_ylabel("Average Cumulative Best Score", fontsize=12)
    ax.set_title(
        "Cumulative Best Score by Attempt: Control vs Budgeted Search", fontsize=14
    )
    ax.legend(fontsize=11)
    ax.grid(True, alpha=0.3)
    ax.set_ylim(-0.05, 1.05)

    plt.tight_layout()
    output_path = os.path.join(output_dir, "analysis2_cumulative_best_by_attempt.png")
    plt.savefig(output_path, dpi=150)
    print(f"Saved: {output_path}")
    plt.close()


def analysis_3_runtime_distribution(control_df, budgeted_df, output_dir):
    """
    Analysis 3: Runtime distribution comparison.
    """

    control_runtime = get_total_runtime(control_df, is_budgeted=False)
    budgeted_runtime = get_total_runtime(budgeted_df, is_budgeted=True)

    if control_runtime.empty and budgeted_runtime.empty:
        print("No data for Analysis 3 (Runtime)")
        return

    fig, ax = plt.subplots(figsize=(10, 6))

    if not control_runtime.empty:
        ax.hist(
            control_runtime["runtime"],
            bins=30,
            alpha=0.5,
            label="Control",
            color="blue",
        )

    if not budgeted_runtime.empty:
        ax.hist(
            budgeted_runtime["runtime"],
            bins=30,
            alpha=0.5,
            label="Budgeted",
            color="orange",
        )

    ax.set_xlabel("Total Runtime (seconds)", fontsize=12)
    ax.set_ylabel("Number of Benchmarks", fontsize=12)
    ax.set_title("Runtime Distribution: Control vs Budgeted Search", fontsize=14)
    ax.legend(fontsize=11)
    ax.grid(True, alpha=0.3)

    plt.tight_layout()
    output_path = os.path.join(output_dir, "analysis3_runtime_distribution.png")
    plt.savefig(output_path, dpi=150)
    print(f"Saved: {output_path}")
    plt.close()


def analysis_4_runtime_discrepancy_budgeted_faster(
    budgeted_faster, output_dir, top_n=5
):
    """
    Analysis 4: Bar chart showing top runtime discrepancies where budgeted is faster.
    """
    if not budgeted_faster:
        print("No data for Analysis 4 (Budgeted Faster)")
        return

    # Take top N
    data = budgeted_faster[:top_n]

    fig, ax = plt.subplots(figsize=(12, 6))

    problems = [d["problem_name"] for d in data]
    control_times = [d["control_runtime"] / 60 for d in data]  # Convert to minutes
    budgeted_times = [d["budgeted_runtime"] / 60 for d in data]

    x = np.arange(len(problems))
    width = 0.35

    bars1 = ax.bar(
        x - width / 2, control_times, width, label="Control", color="blue", alpha=0.7
    )
    bars2 = ax.bar(
        x + width / 2,
        budgeted_times,
        width,
        label="Budgeted",
        color="orange",
        alpha=0.7,
    )

    ax.set_xlabel("Problem", fontsize=16)
    ax.set_ylabel("Runtime (minutes)", fontsize=16)
    ax.set_title(f"Top {len(data)} Cases: Budgeted Faster than Control", fontsize=18)
    ax.set_xticks(x)
    ax.set_xticklabels(problems, rotation=45, ha="right", fontsize=12)
    ax.legend(fontsize=14)
    ax.grid(True, alpha=0.3, axis="y")

    # Add headroom for annotations
    max_height = max(max(control_times), max(budgeted_times))
    ax.set_ylim(0, max_height * 1.15)

    # Add speedup annotations
    for i, d in enumerate(data):
        speedup = d["speedup"]
        ax.annotate(
            f"{speedup:.1f}x",
            xy=(x[i], max(control_times[i], budgeted_times[i])),
            xytext=(0, 5),
            textcoords="offset points",
            ha="center",
            fontsize=10,
        )

    plt.tight_layout()
    output_path = os.path.join(output_dir, "analysis4_runtime_budgeted_faster.png")
    plt.savefig(output_path, dpi=150)
    print(f"Saved: {output_path}")
    plt.close()


def analysis_5_runtime_discrepancy_control_faster(control_faster, output_dir, top_n=5):
    """
    Analysis 5: Bar chart showing top runtime discrepancies where control is faster.
    """
    if not control_faster:
        print("No data for Analysis 5 (Control Faster)")
        return

    # Take top N
    data = control_faster[:top_n]

    fig, ax = plt.subplots(figsize=(12, 6))

    problems = [d["problem_name"] for d in data]
    control_times = [d["control_runtime"] / 60 for d in data]  # Convert to minutes
    budgeted_times = [d["budgeted_runtime"] / 60 for d in data]

    x = np.arange(len(problems))
    width = 0.35

    bars1 = ax.bar(
        x - width / 2, control_times, width, label="Control", color="blue", alpha=0.7
    )
    bars2 = ax.bar(
        x + width / 2,
        budgeted_times,
        width,
        label="Budgeted",
        color="orange",
        alpha=0.7,
    )

    ax.set_xlabel("Problem", fontsize=16)
    ax.set_ylabel("Runtime (minutes)", fontsize=16)
    ax.set_title(f"Top {len(data)} Cases: Control Faster than Budgeted", fontsize=18)
    ax.set_xticks(x)
    ax.set_xticklabels(problems, rotation=45, ha="right", fontsize=12)
    ax.legend(fontsize=14)
    ax.grid(True, alpha=0.3, axis="y")

    # Add headroom for annotations
    max_height = max(max(control_times), max(budgeted_times))
    ax.set_ylim(0, max_height * 1.15)

    # Add speedup annotations
    for i, d in enumerate(data):
        speedup = d["speedup"]
        ax.annotate(
            f"{speedup:.1f}x",
            xy=(x[i], max(control_times[i], budgeted_times[i])),
            xytext=(0, 5),
            textcoords="offset points",
            ha="center",
            fontsize=10,
        )

    plt.tight_layout()
    output_path = os.path.join(output_dir, "analysis5_runtime_control_faster.png")
    plt.savefig(output_path, dpi=150)
    print(f"Saved: {output_path}")
    plt.close()


def analysis_6_time_vs_percent_solved(
    control_df, budgeted_df, output_dir, control_total=148, budgeted_total=147
):
    """
    Analysis 6: Scatter plot showing time (minutes) vs percent of benchmarks solved.
    """
    if control_df.empty and budgeted_df.empty:
        print("No data for Analysis 6 (Time vs Percent Solved)")
        return

    fig, ax = plt.subplots(figsize=(10, 6))

    max_percent = 0  # Track maximum percentage for y-axis scaling

    # Get runtimes for solved benchmarks (score == 1.0)
    if not control_df.empty:
        control_runtime = get_total_runtime(control_df, is_budgeted=False)
        control_final = get_final_scores(control_df, is_budgeted=False)

        if not control_runtime.empty and not control_final.empty:
            merged_control = pd.merge(control_runtime, control_final, on="problem_name")
            solved_control = merged_control[merged_control["final_score"] == 1.0].copy()
            solved_control = solved_control.sort_values("runtime")

            if not solved_control.empty:
                times_seconds = solved_control["runtime"].values
                cumulative_solved = np.arange(1, len(solved_control) + 1)
                percent_solved = (cumulative_solved / control_total) * 100
                max_percent = max(max_percent, percent_solved[-1])

                ax.scatter(
                    times_seconds,
                    percent_solved,
                    color="blue",
                    label=f"Control (n={len(solved_control)}/{control_total})",
                    s=50,
                    marker="o",
                    alpha=0.7,
                    zorder=3,
                )

    if not budgeted_df.empty:
        budgeted_runtime = get_total_runtime(budgeted_df, is_budgeted=True)
        budgeted_final = get_final_scores(budgeted_df, is_budgeted=True)

        if not budgeted_runtime.empty and not budgeted_final.empty:
            merged_budgeted = pd.merge(
                budgeted_runtime, budgeted_final, on="problem_name"
            )
            solved_budgeted = merged_budgeted[
                merged_budgeted["final_score"] == 1.0
            ].copy()
            solved_budgeted = solved_budgeted.sort_values("runtime")

            if not solved_budgeted.empty:
                times_seconds = solved_budgeted["runtime"].values
                cumulative_solved = np.arange(1, len(solved_budgeted) + 1)
                percent_solved = (cumulative_solved / budgeted_total) * 100
                max_percent = max(max_percent, percent_solved[-1])

                ax.scatter(
                    times_seconds,
                    percent_solved,
                    color="orange",
                    label=f"Budgeted (n={len(solved_budgeted)}/{budgeted_total})",
                    s=50,
                    marker="s",
                    alpha=0.7,
                    zorder=3,
                )

    ax.set_xlabel("Time (seconds, log scale)", fontsize=12)
    ax.set_ylabel("Percent of Benchmarks Solved (%)", fontsize=12)
    ax.set_title("Time vs Percent of Benchmarks Solved (score=1.0)", fontsize=14)
    ax.legend(fontsize=11)
    ax.grid(True, alpha=0.3, which="both")
    ax.set_xscale("log")
    # Zoom in: set y-axis max to the maximum percentage + small padding
    ax.set_ylim(0, max_percent * 1.05 if max_percent > 0 else 100)

    plt.tight_layout()
    output_path = os.path.join(output_dir, "analysis6_time_vs_percent_solved.png")
    plt.savefig(output_path, dpi=150)
    print(f"Saved: {output_path}")
    plt.close()


def analysis_7_iterations_vs_percent_solved(
    control_df,
    budgeted_df,
    output_dir,
    control_total=148,
    budgeted_total=147,
    iterations_per_attempt_budgeted=10000,
    iterations_per_attempt_control=10000,
):
    """
    Analysis 7: Scatter plot showing iterations vs percent of benchmarks solved.
    Uses attempt * iterations_per_attempt for both since individual iterations aren't always recorded.
    """
    if control_df.empty and budgeted_df.empty:
        print("No data for Analysis 7 (Iterations vs Percent Solved)")
        return

    fig, ax = plt.subplots(figsize=(10, 6))

    max_percent = 0  # Track maximum percentage for y-axis scaling

    # Process control data
    if not control_df.empty:
        control_final = get_final_scores(control_df, is_budgeted=False)

        if not control_final.empty:
            # For each solved problem, calculate iterations from attempts
            solved_iterations = []
            for problem_name in control_final[control_final["final_score"] == 1.0][
                "problem_name"
            ]:
                problem_df = control_df[control_df["problem_name"] == problem_name]
                attempts_df = problem_df[problem_df["attempt"] > 0].sort_values(
                    "attempt"
                )

                # Count attempts until solved (each attempt = iterations_per_attempt_control)
                total_iters = 0
                for _, row in attempts_df.iterrows():
                    total_iters += iterations_per_attempt_control
                    if row["program_score"] == 1.0:
                        solved_iterations.append(total_iters)
                        break

            if solved_iterations:
                solved_iterations.sort()
                iterations_array = np.array(solved_iterations)
                cumulative_solved = np.arange(1, len(solved_iterations) + 1)
                percent_solved = (cumulative_solved / control_total) * 100
                max_percent = max(max_percent, percent_solved[-1])

                ax.scatter(
                    iterations_array,
                    percent_solved,
                    color="blue",
                    label=f"Control (n={len(solved_iterations)}/{control_total})",
                    s=50,
                    marker="o",
                    alpha=0.7,
                    zorder=3,
                )

    # Process budgeted data
    if not budgeted_df.empty:
        budgeted_final = get_final_scores(budgeted_df, is_budgeted=True)

        if not budgeted_final.empty:
            # For each solved problem, calculate iterations from attempts
            solved_iterations = []
            for problem_name in budgeted_final[budgeted_final["final_score"] == 1.0][
                "problem_name"
            ]:
                problem_df = budgeted_df[budgeted_df["problem_name"] == problem_name]
                attempts_df = problem_df[problem_df["attempt"] > 0].sort_values(
                    "attempt"
                )

                # Count attempts until solved (each attempt = iterations_per_attempt_budgeted)
                total_iters = 0
                for _, row in attempts_df.iterrows():
                    total_iters += iterations_per_attempt_budgeted
                    if row["program_score"] == 1.0:
                        solved_iterations.append(total_iters)
                        break

            if solved_iterations:
                solved_iterations.sort()
                iterations_array = np.array(solved_iterations)
                cumulative_solved = np.arange(1, len(solved_iterations) + 1)
                percent_solved = (cumulative_solved / budgeted_total) * 100
                max_percent = max(max_percent, percent_solved[-1])

                ax.scatter(
                    iterations_array,
                    percent_solved,
                    color="orange",
                    label=f"Budgeted (n={len(solved_iterations)}/{budgeted_total})",
                    s=50,
                    marker="s",
                    alpha=0.7,
                    zorder=3,
                )

    ax.set_xlabel("Iterations (log scale)", fontsize=12)
    ax.set_ylabel("Percent of Benchmarks Solved (%)", fontsize=12)
    ax.set_title("Iterations vs Percent of Benchmarks Solved (score=1.0)", fontsize=14)
    ax.legend(fontsize=11)
    ax.grid(True, alpha=0.3, which="both")
    ax.set_xscale("log")
    # Zoom in: set y-axis max to the maximum percentage + small padding
    ax.set_ylim(0, max_percent * 1.05 if max_percent > 0 else 100)

    plt.tight_layout()
    output_path = os.path.join(output_dir, "analysis7_iterations_vs_percent_solved.png")
    plt.savefig(output_path, dpi=150)
    print(f"Saved: {output_path}")
    plt.close()


def compute_cumulative_best_per_attempt(df):
    """
    For each problem, compute the cumulative best score at each attempt.
    Then average across all problems.
    """

    # Filter out summary rows (attempt <= 0)
    attempts_df = df[df["attempt"] > 0].copy()

    if attempts_df.empty:
        return pd.DataFrame()

    # For each problem, compute cumulative best
    cumulative_data = []
    for problem_name in attempts_df["problem_name"].unique():
        problem_df = attempts_df[
            attempts_df["problem_name"] == problem_name
        ].sort_values("attempt")

        cumulative_best = -1.0
        for _, row in problem_df.iterrows():
            cumulative_best = max(cumulative_best, row["program_score"])
            cumulative_data.append(
                {
                    "problem_name": problem_name,
                    "attempt": row["attempt"],
                    "cumulative_best": cumulative_best,
                }
            )

    cumulative_df = pd.DataFrame(cumulative_data)

    if cumulative_df.empty:
        return pd.DataFrame()

    # Average across problems for each attempt
    avg_by_attempt = (
        cumulative_df.groupby("attempt")
        .agg(
            avg_cumulative_best=("cumulative_best", "mean"),
            std_cumulative_best=("cumulative_best", "std"),
        )
        .reset_index()
    )

    # Fill NaN std with 0
    avg_by_attempt["std_cumulative_best"] = avg_by_attempt[
        "std_cumulative_best"
    ].fillna(0)

    return avg_by_attempt


def compute_statistics(
    control_df, budgeted_df, num_control_files, num_budgeted_files, expected_total=204
):
    """Compute all requested statistics."""
    stats = {}

    # Control statistics
    control_final = get_final_scores(control_df, is_budgeted=False)
    control_timeout = get_timeout_info(control_df)
    control_runtime = get_total_runtime(control_df, is_budgeted=False)

    stats["control"] = {
        "files_found": num_control_files,
        "expected_total": expected_total,
        "runs_completed": len(control_final),
        "runs_missing": expected_total - num_control_files,
        "passed_threshold": len(control_final[control_final["final_score"] >= 0.2])
        if not control_final.empty
        else 0,
        "solved_perfect": len(control_final[control_final["final_score"] == 1.0])
        if not control_final.empty
        else 0,
        "timed_out": len(control_timeout[control_timeout["timed_out"] == True])
        if not control_timeout.empty
        else 0,
        "not_timed_out": len(control_timeout[control_timeout["timed_out"] == False])
        if not control_timeout.empty
        else 0,
        "avg_score": control_final["final_score"].mean()
        if not control_final.empty
        else 0,
        "median_score": control_final["final_score"].median()
        if not control_final.empty
        else 0,
        "std_score": control_final["final_score"].std()
        if not control_final.empty
        else 0,
        "avg_runtime": control_runtime["runtime"].mean()
        if not control_runtime.empty
        else 0,
        "total_runtime": control_runtime["runtime"].sum()
        if not control_runtime.empty
        else 0,
    }

    # Budgeted statistics
    budgeted_final = get_final_scores(budgeted_df, is_budgeted=True)
    budgeted_timeout = get_timeout_info(budgeted_df)
    budgeted_runtime = get_total_runtime(budgeted_df, is_budgeted=True)

    stats["budgeted"] = {
        "files_found": num_budgeted_files,
        "expected_total": expected_total,
        "runs_completed": len(budgeted_final),
        "runs_missing": expected_total - num_budgeted_files,
        "passed_threshold": len(budgeted_final[budgeted_final["final_score"] >= 0.2])
        if not budgeted_final.empty
        else 0,
        "solved_perfect": len(budgeted_final[budgeted_final["final_score"] == 1.0])
        if not budgeted_final.empty
        else 0,
        "timed_out": len(budgeted_timeout[budgeted_timeout["timed_out"] == True])
        if not budgeted_timeout.empty
        else 0,
        "not_timed_out": len(budgeted_timeout[budgeted_timeout["timed_out"] == False])
        if not budgeted_timeout.empty
        else 0,
        "avg_score": budgeted_final["final_score"].mean()
        if not budgeted_final.empty
        else 0,
        "median_score": budgeted_final["final_score"].median()
        if not budgeted_final.empty
        else 0,
        "std_score": budgeted_final["final_score"].std()
        if not budgeted_final.empty
        else 0,
        "avg_runtime": budgeted_runtime["runtime"].mean()
        if not budgeted_runtime.empty
        else 0,
        "total_runtime": budgeted_runtime["runtime"].sum()
        if not budgeted_runtime.empty
        else 0,
    }

    # Comparison statistics
    if not control_final.empty and not budgeted_final.empty:
        merged = pd.merge(
            control_final,
            budgeted_final,
            on="problem_name",
            suffixes=("_control", "_budgeted"),
        )
        if not merged.empty:
            stats["comparison"] = {
                "common_benchmarks": len(merged),
                "budgeted_better": len(
                    merged[
                        merged["final_score_budgeted"] > merged["final_score_control"]
                    ]
                ),
                "control_better": len(
                    merged[
                        merged["final_score_control"] > merged["final_score_budgeted"]
                    ]
                ),
                "ties": len(
                    merged[
                        merged["final_score_control"] == merged["final_score_budgeted"]
                    ]
                ),
            }

    return stats


def write_statistics_file(stats, output_dir):
    """Write statistics to a text file."""
    output_path = os.path.join(output_dir, "statistics.txt")

    with open(output_path, "w") as f:
        f.write("=" * 70 + "\n")
        f.write("EXPERIMENT STATISTICS\n")
        f.write("=" * 70 + "\n\n")

        # Control stats
        f.write("CONTROL RUNS\n")
        f.write("-" * 40 + "\n")
        c = stats["control"]
        f.write(
            f"Files found:              {c['files_found']} / {c['expected_total']}\n"
        )
        f.write(f"Runs missing:             {c['runs_missing']}\n")
        f.write(f"Runs completed:           {c['runs_completed']}\n")
        f.write(f"Passed (score >= 0.2):    {c['passed_threshold']}\n")
        f.write(f"Solved perfectly (1.0):   {c['solved_perfect']}\n")
        f.write(f"Timed out:                {c['timed_out']}\n")
        f.write(f"Not timed out:            {c['not_timed_out']}\n")
        f.write(f"Average score:            {c['avg_score']:.4f}\n")
        f.write(f"Median score:             {c['median_score']:.4f}\n")
        f.write(f"Std dev score:            {c['std_score']:.4f}\n")
        f.write(f"Average runtime (s):      {c['avg_runtime']:.2f}\n")
        f.write(f"Total runtime (s):        {c['total_runtime']:.2f}\n")
        f.write("\n")

        # Budgeted stats
        f.write("BUDGETED RUNS\n")
        f.write("-" * 40 + "\n")
        b = stats["budgeted"]
        f.write(
            f"Files found:              {b['files_found']} / {b['expected_total']}\n"
        )
        f.write(f"Runs missing:             {b['runs_missing']}\n")
        f.write(f"Runs completed:           {b['runs_completed']}\n")
        f.write(f"Passed (score >= 0.2):    {b['passed_threshold']}\n")
        f.write(f"Solved perfectly (1.0):   {b['solved_perfect']}\n")
        f.write(f"Timed out:                {b['timed_out']}\n")
        f.write(f"Not timed out:            {b['not_timed_out']}\n")
        f.write(f"Average score:            {b['avg_score']:.4f}\n")
        f.write(f"Median score:             {b['median_score']:.4f}\n")
        f.write(f"Std dev score:            {b['std_score']:.4f}\n")
        f.write(f"Average runtime (s):      {b['avg_runtime']:.2f}\n")
        f.write(f"Total runtime (s):        {b['total_runtime']:.2f}\n")
        f.write("\n")

        # Comparison
        if "comparison" in stats:
            f.write("COMPARISON\n")
            f.write("-" * 40 + "\n")
            comp = stats["comparison"]
            f.write(f"Common benchmarks:        {comp['common_benchmarks']}\n")
            f.write(f"Budgeted better:          {comp['budgeted_better']}\n")
            f.write(f"Control better:           {comp['control_better']}\n")
            f.write(f"Ties:                     {comp['ties']}\n")
            f.write("\n")

        f.write("=" * 70 + "\n")

    print(f"Saved: {output_path}")
    return output_path


def create_comparison_csv(control_df, budgeted_df, output_dir):
    """Create a CSV file comparing budgeted and control results side by side."""
    if control_df.empty and budgeted_df.empty:
        print("No data for comparison CSV")
        return

    # Extract summary data for each problem from budgeted runs
    budgeted_summaries = {}
    if not budgeted_df.empty:
        for problem_name in budgeted_df["problem_name"].unique():
            problem_df = budgeted_df[budgeted_df["problem_name"] == problem_name]

            # Find summary row with "Final result so no updates"
            if "new_updated_rules" in problem_df.columns:
                summary_row = problem_df[
                    problem_df["new_updated_rules"].str.contains(
                        "Final result", na=False
                    )
                ]
                if summary_row.empty and len(problem_df) >= 3:
                    summary_row = problem_df.iloc[[-3]]
            else:
                summary_row = pd.DataFrame()

            if not summary_row.empty:
                row = summary_row.iloc[0]
                # Count iterations (rows with attempt > 0)
                iterations = len(problem_df[problem_df["attempt"] > 0])
                budgeted_summaries[problem_name] = {
                    "runtime": row.get("time", 0),
                    "iterations": iterations,
                    "best_program": row.get("best_program", ""),
                    "best_score": row.get("program_score", 0),
                }

    # Extract summary data for each problem from control runs
    control_summaries = {}
    if not control_df.empty:
        for problem_name in control_df["problem_name"].unique():
            problem_df = control_df[control_df["problem_name"] == problem_name]

            # Summary row has attempt=-1
            summary_row = problem_df[problem_df["attempt"] == -1]

            if not summary_row.empty:
                row = summary_row.iloc[0]
                # Count iterations (rows with attempt > 0)
                iterations = len(problem_df[problem_df["attempt"] > 0])
                control_summaries[problem_name] = {
                    "runtime": row.get("time_seconds", 0),
                    "iterations": iterations,
                    "best_program": row.get("best_program", ""),
                    "best_score": row.get("program_score", 0),
                }

    # Combine into comparison DataFrame
    all_problems = set(budgeted_summaries.keys()) | set(control_summaries.keys())

    comparison_data = []
    for problem_name in sorted(all_problems):
        row = {"problem_name": problem_name}

        # Budgeted columns
        if problem_name in budgeted_summaries:
            b = budgeted_summaries[problem_name]
            row["budgeted_runtime"] = b["runtime"]
            row["budgeted_iterations"] = b["iterations"]
            row["budgeted_best_program"] = b["best_program"]
            row["budgeted_best_score"] = b["best_score"]
        else:
            row["budgeted_runtime"] = None
            row["budgeted_iterations"] = None
            row["budgeted_best_program"] = None
            row["budgeted_best_score"] = None

        # Control columns
        if problem_name in control_summaries:
            c = control_summaries[problem_name]
            row["control_runtime"] = c["runtime"]
            row["control_iterations"] = c["iterations"]
            row["control_best_program"] = c["best_program"]
            row["control_best_score"] = c["best_score"]
        else:
            row["control_runtime"] = None
            row["control_iterations"] = None
            row["control_best_program"] = None
            row["control_best_score"] = None

        comparison_data.append(row)

    comparison_df = pd.DataFrame(comparison_data)

    # Reorder columns for easier reading
    column_order = [
        "problem_name",
        "budgeted_runtime",
        "budgeted_iterations",
        "budgeted_best_program",
        "budgeted_best_score",
        "control_runtime",
        "control_iterations",
        "control_best_program",
        "control_best_score",
    ]
    comparison_df = comparison_df[column_order]

    output_path = os.path.join(output_dir, "comparison.csv")
    comparison_df.to_csv(output_path, index=False)
    print(f"Saved: {output_path}")

    return comparison_df


def find_intermediate_discrepancies(results_dir, output_dir):
    """
    Compare budgeted vs control CSV files attempt-by-attempt.
    Find cases where one method has a better score at the same attempt number.

    Returns discrepancies for both directions (budgeted better, control better).
    """
    import re

    control_files = glob.glob(os.path.join(results_dir, "*_control*.csv"))
    budgeted_files = glob.glob(os.path.join(results_dir, "*_budgeted*.csv"))

    # Extract problem names from filenames
    def extract_problem_name(filename, search_type):
        basename = os.path.basename(filename)
        # Handle patterns like: problem_name_control_d5_s5.csv or problem_name_budgeted_d5_s5.csv
        pattern = rf"(.+?)_{search_type}_d\d+_s\d+\.csv"
        match = re.match(pattern, basename)
        if match:
            return match.group(1)
        # Fallback to old pattern
        return basename.replace(f"_{search_type}_sizebased.csv", "").replace(
            f"_{search_type}.csv", ""
        )

    # Build dictionaries mapping problem name to file path
    control_by_problem = {extract_problem_name(f, "control"): f for f in control_files}
    budgeted_by_problem = {
        extract_problem_name(f, "budgeted"): f for f in budgeted_files
    }

    # Find common problems
    common_problems = set(control_by_problem.keys()) & set(budgeted_by_problem.keys())

    budgeted_better = []
    control_better = []

    for problem_name in sorted(common_problems):
        control_file = control_by_problem[problem_name]
        budgeted_file = budgeted_by_problem[problem_name]

        try:
            control_df = pd.read_csv(control_file)
            budgeted_df = pd.read_csv(budgeted_file)
        except Exception as e:
            print(f"Error loading files for {problem_name}: {e}")
            continue

        # Get attempt rows only (attempt > 0)
        control_attempts = control_df[control_df["attempt"] > 0].copy()
        budgeted_attempts = budgeted_df[budgeted_df["attempt"] > 0].copy()

        if control_attempts.empty or budgeted_attempts.empty:
            continue

        # Compute cumulative best score for each attempt
        control_attempts = control_attempts.sort_values("attempt")
        budgeted_attempts = budgeted_attempts.sort_values("attempt")

        control_cumulative = {}
        cumulative_best = -1.0
        for _, row in control_attempts.iterrows():
            cumulative_best = max(cumulative_best, row["program_score"])
            control_cumulative[int(row["attempt"])] = cumulative_best

        budgeted_cumulative = {}
        cumulative_best = -1.0
        for _, row in budgeted_attempts.iterrows():
            cumulative_best = max(cumulative_best, row["program_score"])
            budgeted_cumulative[int(row["attempt"])] = cumulative_best

        # Compare at each common attempt
        common_attempts = set(control_cumulative.keys()) & set(
            budgeted_cumulative.keys()
        )

        budgeted_wins = []
        control_wins = []
        for attempt in sorted(common_attempts):
            control_score = control_cumulative[attempt]
            budgeted_score = budgeted_cumulative[attempt]

            if budgeted_score > control_score:
                budgeted_wins.append(
                    {
                        "attempt": attempt,
                        "budgeted_score": budgeted_score,
                        "control_score": control_score,
                        "difference": budgeted_score - control_score,
                    }
                )
            elif control_score > budgeted_score:
                control_wins.append(
                    {
                        "attempt": attempt,
                        "budgeted_score": budgeted_score,
                        "control_score": control_score,
                        "difference": control_score - budgeted_score,
                    }
                )

        # Get final scores
        control_final = max(control_cumulative.values()) if control_cumulative else 0
        budgeted_final = max(budgeted_cumulative.values()) if budgeted_cumulative else 0

        if budgeted_wins:
            budgeted_better.append(
                {
                    "problem_name": problem_name,
                    "control_file": os.path.basename(control_file),
                    "budgeted_file": os.path.basename(budgeted_file),
                    "control_final_score": control_final,
                    "budgeted_final_score": budgeted_final,
                    "num_attempts_better": len(budgeted_wins),
                    "sum_difference": sum(d["difference"] for d in budgeted_wins),
                    "max_difference": max(d["difference"] for d in budgeted_wins),
                    "first_better_attempt": budgeted_wins[0]["attempt"],
                    "details": budgeted_wins,
                }
            )

        if control_wins:
            control_better.append(
                {
                    "problem_name": problem_name,
                    "control_file": os.path.basename(control_file),
                    "budgeted_file": os.path.basename(budgeted_file),
                    "control_final_score": control_final,
                    "budgeted_final_score": budgeted_final,
                    "num_attempts_better": len(control_wins),
                    "sum_difference": sum(d["difference"] for d in control_wins),
                    "max_difference": max(d["difference"] for d in control_wins),
                    "first_better_attempt": control_wins[0]["attempt"],
                    "details": control_wins,
                }
            )

    # Sort by sum of differences (most significant first)
    budgeted_better.sort(key=lambda x: x["sum_difference"], reverse=True)
    control_better.sort(key=lambda x: x["sum_difference"], reverse=True)

    # Write results to file
    output_path = os.path.join(output_dir, "intermediate_discrepancies.txt")
    with open(output_path, "w") as f:
        f.write("=" * 80 + "\n")
        f.write("INTERMEDIATE SCORE DISCREPANCIES\n")
        f.write("=" * 80 + "\n\n")

        f.write(f"Total problems compared: {len(common_problems)}\n")
        f.write(
            f"Problems where budgeted was better at some attempt: {len(budgeted_better)}\n"
        )
        f.write(
            f"Problems where control was better at some attempt: {len(control_better)}\n\n"
        )

        # Top 5 where budgeted is better
        f.write("=" * 80 + "\n")
        f.write("TOP 5: BUDGETED BETTER THAN CONTROL (by sum of score differences)\n")
        f.write("=" * 80 + "\n\n")

        if not budgeted_better:
            f.write("No cases found where budgeted outperformed control.\n\n")
        else:
            for disc in budgeted_better[:5]:
                f.write("-" * 80 + "\n")
                f.write(f"Problem: {disc['problem_name']}\n")
                f.write(f"  Control file:  {disc['control_file']}\n")
                f.write(f"  Budgeted file: {disc['budgeted_file']}\n")
                f.write(
                    f"  Final scores:  Control={disc['control_final_score']:.4f}, Budgeted={disc['budgeted_final_score']:.4f}\n"
                )
                f.write(
                    f"  Attempts where budgeted was better: {disc['num_attempts_better']}\n"
                )
                f.write(f"  Sum of score differences: {disc['sum_difference']:.4f}\n")
                f.write(f"  Max score difference: {disc['max_difference']:.4f}\n")
                f.write(f"  First better at attempt: {disc['first_better_attempt']}\n")
                f.write(f"\n  Attempt-by-attempt details (budgeted > control):\n")
                for detail in disc["details"][:10]:  # Limit to first 10
                    f.write(
                        f"    Attempt {detail['attempt']:3d}: Budgeted={detail['budgeted_score']:.4f}, Control={detail['control_score']:.4f}, Diff=+{detail['difference']:.4f}\n"
                    )
                if len(disc["details"]) > 10:
                    f.write(f"    ... and {len(disc['details']) - 10} more attempts\n")
                f.write("\n")

        # Top 5 where control is better
        f.write("=" * 80 + "\n")
        f.write("TOP 5: CONTROL BETTER THAN BUDGETED (by sum of score differences)\n")
        f.write("=" * 80 + "\n\n")

        if not control_better:
            f.write("No cases found where control outperformed budgeted.\n\n")
        else:
            for disc in control_better[:5]:
                f.write("-" * 80 + "\n")
                f.write(f"Problem: {disc['problem_name']}\n")
                f.write(f"  Control file:  {disc['control_file']}\n")
                f.write(f"  Budgeted file: {disc['budgeted_file']}\n")
                f.write(
                    f"  Final scores:  Control={disc['control_final_score']:.4f}, Budgeted={disc['budgeted_final_score']:.4f}\n"
                )
                f.write(
                    f"  Attempts where control was better: {disc['num_attempts_better']}\n"
                )
                f.write(f"  Sum of score differences: {disc['sum_difference']:.4f}\n")
                f.write(f"  Max score difference: {disc['max_difference']:.4f}\n")
                f.write(f"  First better at attempt: {disc['first_better_attempt']}\n")
                f.write(f"\n  Attempt-by-attempt details (control > budgeted):\n")
                for detail in disc["details"][:10]:  # Limit to first 10
                    f.write(
                        f"    Attempt {detail['attempt']:3d}: Control={detail['control_score']:.4f}, Budgeted={detail['budgeted_score']:.4f}, Diff=+{detail['difference']:.4f}\n"
                    )
                if len(disc["details"]) > 10:
                    f.write(f"    ... and {len(disc['details']) - 10} more attempts\n")
                f.write("\n")

        f.write("=" * 80 + "\n")

    print(f"Saved: {output_path}")

    # Also create CSV summaries
    if budgeted_better:
        summary_data = [
            {
                "problem_name": d["problem_name"],
                "control_final_score": d["control_final_score"],
                "budgeted_final_score": d["budgeted_final_score"],
                "num_attempts_better": d["num_attempts_better"],
                "sum_difference": d["sum_difference"],
                "max_difference": d["max_difference"],
                "first_better_attempt": d["first_better_attempt"],
            }
            for d in budgeted_better
        ]
        csv_path = os.path.join(output_dir, "discrepancies_budgeted_better.csv")
        pd.DataFrame(summary_data).to_csv(csv_path, index=False)
        print(f"Saved: {csv_path}")

    if control_better:
        summary_data = [
            {
                "problem_name": d["problem_name"],
                "control_final_score": d["control_final_score"],
                "budgeted_final_score": d["budgeted_final_score"],
                "num_attempts_better": d["num_attempts_better"],
                "sum_difference": d["sum_difference"],
                "max_difference": d["max_difference"],
                "first_better_attempt": d["first_better_attempt"],
            }
            for d in control_better
        ]
        csv_path = os.path.join(output_dir, "discrepancies_control_better.csv")
        pd.DataFrame(summary_data).to_csv(csv_path, index=False)
        print(f"Saved: {csv_path}")

    return budgeted_better, control_better


def find_runtime_discrepancies(results_dir, output_dir):
    """
    Compare budgeted vs control runtimes, excluding timed-out runs.
    Find cases where one method was significantly faster.

    Returns discrepancies for both directions (budgeted faster, control faster).
    """
    import re

    control_files = glob.glob(os.path.join(results_dir, "*_control*.csv"))
    budgeted_files = glob.glob(os.path.join(results_dir, "*_budgeted*.csv"))

    # Extract problem names from filenames
    def extract_problem_name(filename, search_type):
        basename = os.path.basename(filename)
        pattern = rf"(.+?)_{search_type}_d\d+_s\d+\.csv"
        match = re.match(pattern, basename)
        if match:
            return match.group(1)
        return basename.replace(f"_{search_type}_sizebased.csv", "").replace(
            f"_{search_type}.csv", ""
        )

    # Build dictionaries mapping problem name to file path
    control_by_problem = {extract_problem_name(f, "control"): f for f in control_files}
    budgeted_by_problem = {
        extract_problem_name(f, "budgeted"): f for f in budgeted_files
    }

    # Find common problems
    common_problems = set(control_by_problem.keys()) & set(budgeted_by_problem.keys())

    budgeted_faster = []
    control_faster = []
    excluded_timeout = []

    for problem_name in sorted(common_problems):
        control_file = control_by_problem[problem_name]
        budgeted_file = budgeted_by_problem[problem_name]

        try:
            control_df = pd.read_csv(control_file)
            budgeted_df = pd.read_csv(budgeted_file)
        except Exception as e:
            print(f"Error loading files for {problem_name}: {e}")
            continue

        # Check for timeout in control (attempt=-2 row with "true" in best_program)
        control_timeout = False
        timeout_row = control_df[control_df["attempt"] == -2]
        if not timeout_row.empty:
            best_program = str(timeout_row.iloc[0].get("best_program", ""))
            control_timeout = "true" in best_program.lower()

        # Check for timeout in budgeted (look for timeout indicator)
        budgeted_timeout = False
        if "new_updated_rules" in budgeted_df.columns:
            timeout_rows = budgeted_df[
                budgeted_df["new_updated_rules"].str.contains(
                    "Timeout", na=False, case=False
                )
            ]
            budgeted_timeout = not timeout_rows.empty
        # Also check attempt=-2 row if exists
        timeout_row = budgeted_df[budgeted_df["attempt"] == -2]
        if not timeout_row.empty:
            best_program = str(timeout_row.iloc[0].get("best_program", ""))
            if "true" in best_program.lower():
                budgeted_timeout = True

        # Exclude if either timed out
        if control_timeout or budgeted_timeout:
            excluded_timeout.append(
                {
                    "problem_name": problem_name,
                    "control_timeout": control_timeout,
                    "budgeted_timeout": budgeted_timeout,
                }
            )
            continue

        # Get control runtime from summary row (attempt=-1)
        control_runtime = None
        summary_row = control_df[control_df["attempt"] == -1]
        if not summary_row.empty:
            control_runtime = summary_row.iloc[0].get("time_seconds", None)

        # Get budgeted runtime from "Final result" row
        budgeted_runtime = None
        if "new_updated_rules" in budgeted_df.columns:
            final_row = budgeted_df[
                budgeted_df["new_updated_rules"].str.contains("Final result", na=False)
            ]
            if not final_row.empty:
                budgeted_runtime = final_row.iloc[0].get("time", None)

        if control_runtime is None or budgeted_runtime is None:
            continue

        # Get final scores
        control_score = None
        budgeted_score = None
        if not summary_row.empty:
            control_score = summary_row.iloc[0].get("program_score", 0)
        if "new_updated_rules" in budgeted_df.columns:
            final_row = budgeted_df[
                budgeted_df["new_updated_rules"].str.contains("Final result", na=False)
            ]
            if not final_row.empty:
                budgeted_score = final_row.iloc[0].get("program_score", 0)

        time_diff = control_runtime - budgeted_runtime  # positive means budgeted faster
        speedup = (
            control_runtime / budgeted_runtime if budgeted_runtime > 0 else float("inf")
        )

        entry = {
            "problem_name": problem_name,
            "control_file": os.path.basename(control_file),
            "budgeted_file": os.path.basename(budgeted_file),
            "control_runtime": control_runtime,
            "budgeted_runtime": budgeted_runtime,
            "control_score": control_score,
            "budgeted_score": budgeted_score,
            "time_difference": abs(time_diff),
            "speedup": speedup if time_diff > 0 else 1 / speedup if speedup > 0 else 0,
        }

        if time_diff > 0:  # budgeted faster
            budgeted_faster.append(entry)
        elif time_diff < 0:  # control faster
            entry["speedup"] = (
                budgeted_runtime / control_runtime
                if control_runtime > 0
                else float("inf")
            )
            control_faster.append(entry)

    # Sort by time difference (largest first)
    budgeted_faster.sort(key=lambda x: x["time_difference"], reverse=True)
    control_faster.sort(key=lambda x: x["time_difference"], reverse=True)

    # Write results to file
    output_path = os.path.join(output_dir, "runtime_discrepancies.txt")
    with open(output_path, "w") as f:
        f.write("=" * 80 + "\n")
        f.write("RUNTIME DISCREPANCIES (excluding timed-out runs)\n")
        f.write("=" * 80 + "\n\n")

        f.write(f"Total problems compared: {len(common_problems)}\n")
        f.write(f"Excluded due to timeout: {len(excluded_timeout)}\n")
        f.write(f"Problems where budgeted was faster: {len(budgeted_faster)}\n")
        f.write(f"Problems where control was faster: {len(control_faster)}\n\n")

        # Top 5 where budgeted is faster
        f.write("=" * 80 + "\n")
        f.write("TOP 5: BUDGETED FASTER THAN CONTROL (by time saved)\n")
        f.write("=" * 80 + "\n\n")

        if not budgeted_faster:
            f.write("No cases found where budgeted was faster.\n\n")
        else:
            for entry in budgeted_faster[:5]:
                f.write("-" * 80 + "\n")
                f.write(f"Problem: {entry['problem_name']}\n")
                f.write(f"  Control runtime:  {entry['control_runtime']:.2f}s\n")
                f.write(f"  Budgeted runtime: {entry['budgeted_runtime']:.2f}s\n")
                f.write(
                    f"  Time saved:       {entry['time_difference']:.2f}s ({entry['speedup']:.2f}x faster)\n"
                )
                f.write(
                    f"  Final scores:     Control={entry['control_score']:.4f}, Budgeted={entry['budgeted_score']:.4f}\n"
                )
                f.write("\n")

        # Top 5 where control is faster
        f.write("=" * 80 + "\n")
        f.write("TOP 5: CONTROL FASTER THAN BUDGETED (by time saved)\n")
        f.write("=" * 80 + "\n\n")

        if not control_faster:
            f.write("No cases found where control was faster.\n\n")
        else:
            for entry in control_faster[:5]:
                f.write("-" * 80 + "\n")
                f.write(f"Problem: {entry['problem_name']}\n")
                f.write(f"  Control runtime:  {entry['control_runtime']:.2f}s\n")
                f.write(f"  Budgeted runtime: {entry['budgeted_runtime']:.2f}s\n")
                f.write(
                    f"  Time saved:       {entry['time_difference']:.2f}s ({entry['speedup']:.2f}x faster)\n"
                )
                f.write(
                    f"  Final scores:     Control={entry['control_score']:.4f}, Budgeted={entry['budgeted_score']:.4f}\n"
                )
                f.write("\n")

        # List excluded timeouts
        if excluded_timeout:
            f.write("=" * 80 + "\n")
            f.write(f"EXCLUDED DUE TO TIMEOUT ({len(excluded_timeout)} problems)\n")
            f.write("=" * 80 + "\n\n")
            for entry in excluded_timeout:
                timeout_info = []
                if entry["control_timeout"]:
                    timeout_info.append("control")
                if entry["budgeted_timeout"]:
                    timeout_info.append("budgeted")
                f.write(
                    f"  {entry['problem_name']}: {', '.join(timeout_info)} timed out\n"
                )
            f.write("\n")

        f.write("=" * 80 + "\n")

    print(f"Saved: {output_path}")

    # Create CSV summaries
    if budgeted_faster:
        csv_path = os.path.join(output_dir, "runtime_budgeted_faster.csv")
        pd.DataFrame(budgeted_faster).to_csv(csv_path, index=False)
        print(f"Saved: {csv_path}")

    if control_faster:
        csv_path = os.path.join(output_dir, "runtime_control_faster.csv")
        pd.DataFrame(control_faster).to_csv(csv_path, index=False)
        print(f"Saved: {csv_path}")

    return budgeted_faster, control_faster, excluded_timeout


def print_summary_statistics(stats):
    """Print summary statistics to console."""

    print("\n" + "=" * 60)
    print("SUMMARY STATISTICS")
    print("=" * 60)

    c = stats["control"]
    print(f"\nCONTROL:")
    print(
        f"  Files found: {c['files_found']} / {c['expected_total']} (missing: {c['runs_missing']})"
    )
    print(f"  Passed (score >= 0.2): {c['passed_threshold']}")
    print(f"  Solved perfectly: {c['solved_perfect']}")
    print(f"  Timed out: {c['timed_out']}")
    print(f"  Average score: {c['avg_score']:.4f}")
    print(f"  Average runtime: {c['avg_runtime']:.2f}s")

    b = stats["budgeted"]
    print(f"\nBUDGETED SEARCH:")
    print(
        f"  Files found: {b['files_found']} / {b['expected_total']} (missing: {b['runs_missing']})"
    )
    print(f"  Passed (score >= 0.2): {b['passed_threshold']}")
    print(f"  Solved perfectly: {b['solved_perfect']}")
    print(f"  Timed out: {b['timed_out']}")
    print(f"  Average score: {b['avg_score']:.4f}")
    print(f"  Average runtime: {b['avg_runtime']:.2f}s")

    if "comparison" in stats:
        comp = stats["comparison"]
        print(f"\nCOMPARISON (on {comp['common_benchmarks']} common benchmarks):")
        print(f"  Budgeted better: {comp['budgeted_better']}")
        print(f"  Control better: {comp['control_better']}")
        print(f"  Ties: {comp['ties']}")

    print("=" * 60 + "\n")


def main():
    if len(sys.argv) < 2:
        print("Usage: python analyze_results.py <results_directory> [output_directory]")
        print(
            "Example: python analyze_results.py ../Data/experimentcommon3local ./plots"
        )
        sys.exit(1)

    results_dir = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "./plots"

    if not os.path.exists(results_dir):
        print(f"Error: Results directory '{results_dir}' does not exist")
        sys.exit(1)

    os.makedirs(output_dir, exist_ok=True)

    print(f"Loading results from: {results_dir}")
    print(f"Saving plots to: {output_dir}")

    control_df, budgeted_df, num_control, num_budgeted = load_csv_files(results_dir)

    if control_df.empty and budgeted_df.empty:
        print("No CSV files found!")
        sys.exit(1)

    # Compute and save statistics
    stats = compute_statistics(control_df, budgeted_df, num_control, num_budgeted)
    print_summary_statistics(stats)
    write_statistics_file(stats, output_dir)

    print("Generating comparison CSV...")
    create_comparison_csv(control_df, budgeted_df, output_dir)

    print("Finding intermediate score discrepancies...")
    find_intermediate_discrepancies(results_dir, output_dir)

    print("Finding runtime discrepancies...")
    budgeted_faster, control_faster, excluded_timeout = find_runtime_discrepancies(
        results_dir, output_dir
    )

    print("Generating Analysis 1: Score Distribution...")
    analysis_1_score_distribution(control_df, budgeted_df, output_dir)

    print("Generating Analysis 2: Cumulative Best by Attempt...")
    analysis_2_cumulative_best_by_attempt(control_df, budgeted_df, output_dir)

    print("Generating Analysis 3: Runtime Distribution...")
    analysis_3_runtime_distribution(control_df, budgeted_df, output_dir)

    print("Generating Analysis 4: Runtime Discrepancy (Budgeted Faster)...")
    analysis_4_runtime_discrepancy_budgeted_faster(budgeted_faster, output_dir)

    print("Generating Analysis 5: Runtime Discrepancy (Control Faster)...")
    analysis_5_runtime_discrepancy_control_faster(control_faster, output_dir)

    print("Generating Analysis 6: Time vs Percent Solved...")
    analysis_6_time_vs_percent_solved(control_df, budgeted_df, output_dir)

    print("Generating Analysis 7: Iterations vs Percent Solved...")
    analysis_7_iterations_vs_percent_solved(control_df, budgeted_df, output_dir)

    print("\nDone!")


if __name__ == "__main__":
    main()
