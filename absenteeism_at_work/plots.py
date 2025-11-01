# absenteeism_at_work/plots.py

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np

from .config import (
    PROCESSED_DATA_PATH, MONTHS, DAYS, SEASONS,
    EDUCATION, YES_NO
)

def create_figure():
    return plt.figure(figsize=(13, 8))

def body_mass_category(bmi):
    if bmi < 18.5:
        return 'Underweight'
    elif bmi < 25:
        return 'Normal'
    elif bmi < 30:
        return 'Overweight'
    else:
        return 'Obese'

# Función auxiliar DRY para los plots
def plot_with_palette(plot_func, *, data, x=None, y=None, col=None, palette=None, ax=None):
    return plot_func(
        data=data,
        x=x,
        y=y,
        hue=col,
        palette=palette,
        legend=False,
        ax=ax
    )

class AbsenteeismVisualizer:
    def __init__(self, filepath=PROCESSED_DATA_PATH):
        self.df = pd.read_csv(filepath)
        self.df_copy = self.df.copy()
        self._prepare_data()

    def _prepare_data(self):
        self.df_copy['Month of absence'] = self.df_copy['Month of absence'].map(MONTHS)
        self.df_copy['Day of the week'] = self.df_copy['Day of the week'].map(DAYS)
        self.df_copy['Seasons'] = self.df_copy['Seasons'].map(SEASONS)
        self.df_copy['Disciplinary failure'] = self.df_copy['Disciplinary failure'].map(YES_NO)
        self.df_copy['Education'] = self.df_copy['Education'].map(EDUCATION)
        self.df_copy['Social drinker'] = self.df_copy['Social drinker'].map(YES_NO)
        self.df_copy['Social smoker'] = self.df_copy['Social smoker'].map(YES_NO)
        self.df_copy['Body mass index'] = self.df_copy['Body mass index'].apply(body_mass_category)

    def plot_distribution(self):
        create_figure()
        self.df_copy['Absenteeism time in hours'].hist()
        plt.title("Distribution of Absenteeism Time", fontsize=16)
        plt.xlabel("Hours")
        plt.ylabel("Frequency")
        plt.grid(axis='y', alpha=0.75)
        plt.show()

    def plot_target_correlations(self):
        numeric_df = self.df.select_dtypes(include=[np.number])
        corr = numeric_df.corr()
        target_corr = corr['Absenteeism time in hours'].drop('Absenteeism time in hours').sort_values()

        create_figure()
        plot_with_palette(
            sns.barplot,
            x=target_corr.values,
            y=target_corr.index,
            col=target_corr.index,
            data=None,
            palette="coolwarm"
        )
        plt.title("Correlation with Absenteeism time in hours", fontsize=16)
        plt.xlabel("Correlation Coefficient")
        plt.ylabel("Features")
        plt.tight_layout()
        plt.show()

    def plot_correlation_heatmap(self):
        numeric_df = self.df.select_dtypes(include=[np.number])
        corr = numeric_df.corr()

        create_figure()
        sns.heatmap(corr, annot=True, cmap="coolwarm", center=0, fmt=".2f", linewidths=.5)
        plt.title("Correlation Matrix", fontsize=16)
        plt.tight_layout()
        plt.show()

    def plot_boxplots_by_category(self):
        categorical_cols = ['Reason for absence', 'Month of absence', 'Day of the week', 'Seasons',
                            'Disciplinary failure', 'Education', 'Son', 'Social drinker', 'Social smoker',
                            'Pet', 'Weight', 'Height', 'Body mass index']

        for col in categorical_cols:
            create_figure()
            plot_with_palette(
                sns.boxplot,
                data=self.df_copy,
                x=col,
                y='Absenteeism time in hours',
                col=col,
                palette="Set2"
            )
            plt.title(f"Absenteeism by {col}", fontsize=14)
            plt.xticks(rotation=45)
            plt.tight_layout()
            plt.show()

    def plot_categorical_distributions(self):
        categorical_cols = ['Month of absence', 'Seasons', 'Education',
                            'Disciplinary failure', 'Social drinker', 'Social smoker']

        create_figure()
        for i, col in enumerate(categorical_cols, 1):
            plt.subplot(3, 2, i)
            plot_with_palette(
                sns.countplot,
                data=self.df_copy,
                x=col,
                col=col,
                palette='viridis'
            )
            plt.title(f'Distribution of {col}')
            plt.xticks(rotation=45)
        plt.tight_layout()
        plt.show()

    def plot_absenteeism_vs_categories(self):
        categorical_cols = ['Month of absence', 'Seasons', 'Education',
                            'Disciplinary failure', 'Social drinker', 'Social smoker']

        create_figure()
        for i, col in enumerate(categorical_cols, 1):
            plt.subplot(3, 2, i)
            plot_with_palette(
                sns.boxplot,
                data=self.df_copy,
                x=col,
                y='Absenteeism time in hours',
                col=col,
                palette='coolwarm'
            )
            plt.title(f'Absenteeism vs {col}')
            plt.xticks(rotation=45)
        plt.tight_layout()
        plt.show()

    def plot_average_absenteeism_by_season(self):
        avg_absence = self.df_copy.groupby('Seasons')['Absenteeism time in hours'].mean().sort_values(ascending=False)

        create_figure()
        plot_with_palette(
            sns.barplot,
            x=avg_absence.index,
            y=avg_absence.values,
            col=avg_absence.index,
            data=None,
            palette='RdYlBu'
        )
        plt.title('Average Absenteeism Time by Season', fontsize=14)
        plt.ylabel('Average Hours')
        plt.xlabel('Season')
        plt.tight_layout()
        plt.show()
