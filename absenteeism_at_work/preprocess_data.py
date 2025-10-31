# absenteeism_at_work/preprocess_data.py

from .dataset import AbsenteeismCleaner

def main():
    print("🛠️ Starting data preprocessing...")
    cleaner = AbsenteeismCleaner()
    df_clean = cleaner.run()
    print("✅ Data preprocessing completed.")

if __name__ == "__main__":
    main()
