# absenteeism_at_work/features.py

import numpy as np
import pandas as pd
from sklearn.base import BaseEstimator, TransformerMixin
from sklearn.pipeline import Pipeline


class DropColumns(BaseEstimator, TransformerMixin):
    def fit(self, X, y=None): return self
    def transform(self, X): return X.drop(['ID', 'mixed_type_col'], axis=1)


class StripObjectColumns(BaseEstimator, TransformerMixin):
    def fit(self, X, y=None): return self
    def transform(self, X):
        df = X.copy()
        for col in df.select_dtypes(include='object'):
            df[col] = df[col].astype(str).str.strip()
        return df


class SafeRoundToInt(BaseEstimator, TransformerMixin):
    def fit(self, X, y=None): return self
    def transform(self, X):
        def safe_convert(val):
            try:
                return round(float(val)) if not pd.isnull(val) else np.nan
            except:
                return np.nan

        df = X.copy()
        for col in df.columns:
            df[col] = df[col].apply(safe_convert)
        return df


class FixInvalidValues(BaseEstimator, TransformerMixin):
    def fit(self, X, y=None): return self
    def transform(self, X):
        df = X.copy()
        df['Reason for absence'] = df['Reason for absence'].apply(lambda x: x if x in range(0, 29) else 0)
        df['Month of absence'] = df['Month of absence'].apply(lambda x: x if x in range(0, 13) else 0)
        df['Day of the week'] = df['Day of the week'].apply(lambda x: x if x in range(2, 7) else df['Day of the week'].mode()[0])
        df['Seasons'] = df['Seasons'].apply(lambda x: x if x in range(1, 5) else df['Seasons'].mode()[0])
        df['Education'] = df['Education'].apply(lambda x: x if x in range(1, 5) else df['Education'].mode()[0])
        for col in ['Disciplinary failure', 'Social drinker', 'Social smoker']:
            df[col] = df[col].apply(lambda x: x if x in [0, 1] else df[col].mode()[0])
        return df


class WinsorizeIQR(BaseEstimator, TransformerMixin):
    def __init__(self):
        self.columns = [
            'Transportation expense', 'Distance from Residence to Work', 'Service time',
            'Age', 'Work load Average/day', 'Hit target', 'Son', 'Pet', 'Weight',
            'Height', 'Body mass index', 'Absenteeism time in hours'
        ]
    def fit(self, X, y=None): return self
    def transform(self, X):
        df = X.copy()
        for col in self.columns:
            Q1 = df[col].quantile(0.25)
            Q3 = df[col].quantile(0.75)
            IQR = Q3 - Q1
            df[col] = df[col].clip(lower=Q1 - 1.5 * IQR, upper=Q3 + 1.5 * IQR)
        return df


class FillNaWithMedian(BaseEstimator, TransformerMixin):
    def fit(self, X, y=None): return self
    def transform(self, X):
        return X.fillna(X.median(numeric_only=True))


class FinalIntConversion(BaseEstimator, TransformerMixin):
    def fit(self, X, y=None): return self
    def transform(self, X):
        return X.round(0).astype(int)


def create_preprocessing_pipeline():
    return Pipeline([
        ('drop_columns', DropColumns()),
        ('strip_objects', StripObjectColumns()),
        ('safe_round', SafeRoundToInt()),
        ('fix_invalids', FixInvalidValues()),
        ('winsorize', WinsorizeIQR()),
        ('fillna', FillNaWithMedian()),
        ('final_int', FinalIntConversion())
    ])
