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






## Project Organization

This project follows the [Cookiecutter Data Science](https://drivendata.github.io/cookiecutter-data-science/) structure for organized and reproducible machine learning projects.

```
├── LICENSE
├── Makefile                          # Standard commands for project operations
├── README.md
├── pyproject.toml                    # Project metadata and build configuration
├── requirements.txt                  # Python dependencies
├── setup.cfg                         # Additional setup configuration
├── .dvcignore                        # Files to ignore in DVC tracking
├── dvc.yaml                          # DVC pipeline definition
├── data
│   ├── external                      # External data sources
│   ├── interim                       # Intermediate data files
│   ├── processed                     # Final, processed datasets
│   │   └── work_absenteeism_processed.csv
│   └── raw                           # Original, immutable data
│       └── work_absenteeism_raw.csv
├── docs
│   ├── Phase1.pdf
│   └── Phase2.pdf
├── models                            # Trained and serialized models
├── notebooks                         # Jupyter notebooks for exploration
│   └── Phase1
│       ├── data_preparation.ipynb
│       ├── eda_fe.ipynb
│       └── model_train.ipynb
├── references                        # Data dictionaries, papers, manuals
├── reports
│   ├── figures                       # Generated graphics and figures
│   └── metrics                       # Model evaluation metrics
├── .dvc/                             # DVC configuration (hidden)
│   ├── config
│   ├── plots/
│   └── tmp/
└── absenteeism_at_work               # Source code package
    ├── __init__.py
    ├── config.py                    # Configuration and constants
    ├── dataset.py                   # Data loading and cleaning
    ├── features.py                  # Feature engineering pipeline
    ├── modeling
    │   ├── __init__.py
    │   ├── predict.py              # Model prediction interface
    │   └── train.py                # Model training pipeline
    ├── plots.py                     # Visualization functions
    ├── preprocess_data.py           # Data preprocessing entry point
    └── visualize_data.py            # Visualization entry point
```

## Quick Start

### Installation

```bash
# Install the package in development mode
make install

# Or with all optional dependencies
make install-dev
```

### Using Make Commands

```bash
# See all available commands
make help

# Preprocess raw data
make preprocess

# Train the model
make train

# Generate visualizations
make visualize

# Run full pipeline
make all

# Run tests
make test

# Format code
make format
```

### Using DVC

```bash
# Pull data versions
make data-pull

# Check data status
make data-version

# Run DVC pipeline
dvc repro
```

## 🚀 Deployment

### Branch Strategy

- **`master`/`main`**: Desarrollo (sin deploy automático)
- **`web`**: Producción (deploy automático a ECS Fargate)

### Deploy to Production

El workflow de GitHub Actions se ejecutará automáticamente al hacer push a la rama `web`:

```bash
# When ready to deploy
git checkout web
git merge master
git push origin web
```

### What Gets Deployed

**1. Absenteeism API** (deploy.yml)
- ✅ **CloudFormation** para infraestructura
- ✅ **ECR** para imágenes Docker (`absenteeism-api`)
- ✅ **ECS Cluster**: `production-absenteeism-cluster`
- ✅ **Application Load Balancer** para alta disponibilidad
- ✅ **Auto-scaling** y health checks
- ✅ **Logs centralizados** en CloudWatch

**2. MLflow Tracking Server** (deploy-mlflow.yml)
- ✅ **CloudFormation** para infraestructura
- ✅ **ECR** para imágenes Docker (`mlflow-tracking`)
- ✅ **ECS Cluster**: `production-mlflow-cluster`
- ✅ **Application Load Balancer** para acceder a la UI
- ✅ **S3** para almacenar artifacts (opcional)
- ✅ **Health checks** para el servidor de tracking

### Troubleshooting

**Ver logs de ECS (API):**
```bash
aws logs tail /ecs/production-absenteeism-api --follow --region us-east-1
```

**Ver logs de ECS (MLflow):**
```bash
aws logs tail /ecs/production-mlflow-tracking --follow --region us-east-1
```

**Verificar estado del servicio (API):**
```bash
aws ecs describe-services \
  --cluster production-absenteeism-cluster \
  --services production-absenteeism-api \
  --region us-east-1
```

**Verificar estado del servicio (MLflow):**
```bash
aws ecs describe-services \
  --cluster production-mlflow-cluster \
  --services production-mlflow-tracking \
  --region us-east-1
```

**Ver outputs de CloudFormation (API):**
```bash
aws cloudformation describe-stacks \
  --stack-name absenteeism-infrastructure \
  --query 'Stacks[0].Outputs' \
  --output table \
  --region us-east-1
```

**Ver outputs de CloudFormation (MLflow):**
```bash
aws cloudformation describe-stacks \
  --stack-name mlflow-infrastructure \
  --query 'Stacks[0].Outputs' \
  --output table \
  --region us-east-1
```

## Project Structure Based on Cookiecutter Data Science

This project follows the standardized structure recommended by [Cookiecutter Data Science](https://drivendata.github.io/cookiecutter-data-science/), which provides:

- **Standardized organization**: Consistent project structure across different ML projects
- **Separation of concerns**: Clear separation between data, code, models, and documentation
- **Reproducibility**: Structured approach to version control and experiment tracking
- **Scalability**: Easy to extend and maintain as the project grows

Key principles implemented:
- Raw data is immutable and versioned with DVC
- Processed data is derived from raw data through documented pipelines
- Code is organized into logical modules
- Models are versioned and tracked with MLflow
- Experiments are reproducible through DVC pipelines

--------

