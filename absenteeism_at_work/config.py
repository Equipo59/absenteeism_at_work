# absenteeism_at_work/config.py

import os

# Paths
DATA_DIR = "data"
RAW_DATA_PATH = os.path.join(DATA_DIR, "raw", "work_absenteeism_raw.csv")
PROCESSED_DATA_PATH = os.path.join(DATA_DIR, "processed", "work_absenteeism_processed.csv")

# Column Mapping Dictionaries
REASON_ABSENCE = {
    0: 'Unknown',
    1: 'Certain infectious and parasitic diseases',
    2: 'Neoplasms',
    3: 'Blood and immune disorders',
    4: 'Endocrine disorders',
    5: 'Mental disorders',
    6: 'Nervous system diseases',
    7: 'Eye diseases',
    8: 'Ear diseases',
    9: 'Circulatory system diseases',
    10: 'Respiratory system diseases',
    11: 'Digestive system diseases',
    12: 'Skin diseases',
    13: 'Musculoskeletal diseases',
    14: 'Genitourinary diseases',
    15: 'Pregnancy and childbirth',
    16: 'Perinatal conditions',
    17: 'Congenital anomalies',
    18: 'Symptoms and signs',
    19: 'Injuries and poisoning',
    20: 'External causes',
    21: 'Health services contact',
    22: 'Patient follow-up',
    23: 'Medical consultation',
    24: 'Blood donation',
    25: 'Lab examination',
    26: 'Unjustified absence',
    27: 'Physiotherapy',
    28: 'Dental consultation'
}

MONTHS = {
    0: 'Unknown', 1: 'January', 2: 'February', 3: 'March', 4: 'April',
    5: 'May', 6: 'June', 7: 'July', 8: 'August',
    9: 'September', 10: 'October', 11: 'November', 12: 'December'
}

DAYS = {2: 'Monday', 3: 'Tuesday', 4: 'Wednesday', 5: 'Thursday', 6: 'Friday'}
SEASONS = {1: 'Winter', 2: 'Spring', 3: 'Summer', 4: 'Fall'}
EDUCATION = {1: 'High School', 2: 'Graduate', 3: 'Postgraduate', 4: 'Master and Doctor'}
YES_NO = {0: 'No', 1: 'Yes'}
