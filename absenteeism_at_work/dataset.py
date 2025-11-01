# absenteeism_at_work/dataset.py

import os
import pandas as pd
from .features import create_preprocessing_pipeline
from .config import RAW_DATA_PATH, PROCESSED_DATA_PATH


class AbsenteeismCleaner:
    def __init__(self, raw_path=RAW_DATA_PATH, processed_path=PROCESSED_DATA_PATH):
        self.raw_path = raw_path
        self.processed_path = processed_path
        self.pipeline = create_preprocessing_pipeline()

    def load_data(self):
        if not os.path.exists(self.raw_path):
            raise FileNotFoundError(f"File not found: {self.raw_path}")
        return pd.read_csv(self.raw_path)

    def clean_data(self, df):
        return self.pipeline.fit_transform(df)

    def save_data(self, df):
        os.makedirs(os.path.dirname(self.processed_path), exist_ok=True)
        df.to_csv(self.processed_path, index=False)
        print(f"✅ Data saved to: {self.processed_path}")

    def run(self):
        print("🚀 Loading data...")
        df_raw = self.load_data()
        print("🧹 Cleaning data...")
        df_clean = self.clean_data(df_raw)
        print("💾 Saving processed data...")
        self.save_data(df_clean)
        return df_clean
