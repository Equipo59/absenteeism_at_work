# absenteeism_at_work/main1.py

from .plots import AbsenteeismVisualizer

def main():
    print("📊 Starting absenteeism data visualizations...")

    visualizer = AbsenteeismVisualizer()

    visualizer.plot_distribution()
    visualizer.plot_target_correlations()
    visualizer.plot_correlation_heatmap()
    visualizer.plot_boxplots_by_category()
    visualizer.plot_categorical_distributions()
    visualizer.plot_absenteeism_vs_categories()
    visualizer.plot_average_absenteeism_by_season()

    print("✅ Visualizations completed successfully.")

if __name__ == "__main__":
    main()
