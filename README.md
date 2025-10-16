# MLOps - Absenteeism at Work


## Project

Model to predict how many hours an employee will be absent.


## Value Proposition

Anticipate absenteeism trends to improve operational planning, reduce costs, and promote employee well-being strategies.


## Roles
**Data Engineer**: Miguel Marines  
**Data Scientist**: Jorge Adrián Acevedo Fonseca  
**Machine Learning Engineer**: Eduardo Javier Porras Herrera  
**Software Engineer**: Carlos Pano Hernández  
**Site Reliability Engineer (DevOps)**: César Manuel Tirado Peraza






## Absenteeism at Work - Project Organization

```
├── LICENSE
├── Makefile
├── README.md
├── data
│   ├── external
│   ├── interim
│   ├── processed
│   │   ├── work_absenteeism_processed.csv
│   │   └── work_absenteeism_processed.csv.dvc
│   └── raw
│       ├── work_absenteeism_raw.csv
│       └── work_absenteeism_raw.csv.dvc
│
├── docs
│   ├── Phase1.pdf
│   └── Phase2.pdf
│
├── models
│
├── notebooks
│   └── Phase1
│       ├── data_preparation.ipynb
│       ├── eda_fe.ipynb
│       └── model_train.ipynb
│
├── pyproject.toml
│
├── references
│
├── reports
│   └── figures
│
├── requirements.txt
│
├── setup.cfg
│
└── absenteeism_at_work
    ├── __init__.py
    ├── config.py
    ├── dataset.py
    ├── features.py
    ├── modeling
    │   ├── __init__.py 
    │   ├── predict.py
    │   └── train.py
    ├── plots.py
    ├── preprocess_data.py
    └── visualize_data.py

```

--------

