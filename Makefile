.PHONY: help install install-dev clean preprocess train predict visualize test lint format check data-download data-version data-pull all

# Default target
help:
	@echo "Available commands:"
	@echo "  make install          - Install the package in development mode"
	@echo "  make install-dev      - Install package with dev dependencies"
	@echo "  make clean            - Remove cache files and build artifacts"
	@echo "  make preprocess       - Preprocess raw data"
	@echo "  make train            - Train the ML model"
	@echo "  make predict          - Run predictions (requires trained model)"
	@echo "  make visualize        - Generate data visualizations"
	@echo "  make test             - Run tests with pytest"
	@echo "  make lint             - Run linter checks"
	@echo "  make format           - Format code with black"
	@echo "  make check            - Run all quality checks"
	@echo "  make data-download    - Download data using DVC"
	@echo "  make data-version     - Show DVC data version info"
	@echo "  make data-pull        - Pull latest data versions with DVC"
	@echo "  make all              - Run full pipeline: preprocess -> train -> evaluate"

# Installation
install:
	pip install -e .

install-dev:
	pip install -e ".[dev,ml,quality]"

# Cleanup
clean:
	find . -type d -name "__pycache__" -exec rm -r {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type d -name "*.egg-info" -exec rm -r {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -r {} + 2>/dev/null || true
	find . -type d -name ".mypy_cache" -exec rm -r {} + 2>/dev/null || true
	rm -rf build/ dist/ *.egg-info/
	rm -rf .coverage htmlcov/
	rm -rf mlruns/
	@echo "✅ Cleanup completed"

# Data operations
preprocess:
	@echo "🔄 Preprocessing data..."
	python -m absenteeism_at_work.preprocess_data

visualize:
	@echo "📊 Generating visualizations..."
	python -m absenteeism_at_work.visualize_data

# Model operations
train:
	@echo "🤖 Training model..."
	python -m absenteeism_at_work.modeling.train

predict:
	@echo "🔮 Running predictions..."
	python -m absenteeism_at_work.modeling.predict

# DVC data operations
data-download:
	@echo "⬇️ Downloading data with DVC..."
	dvc pull

data-version:
	@echo "📋 DVC data versions:"
	dvc status

data-pull:
	@echo "📥 Pulling latest data versions..."
	dvc pull

# Testing and quality
test:
	@echo "🧪 Running tests..."
	pytest

lint:
	@echo "🔍 Running linters..."
	flake8 absenteeism_at_work tests --max-line-length=88 --exclude=__pycache__
	mypy absenteeism_at_work --ignore-missing-imports

format:
	@echo "✨ Formatting code..."
	black absenteeism_at_work tests

check: lint test
	@echo "✅ All checks passed"

# Full pipeline
all: clean preprocess train
	@echo "✅ Full pipeline completed!"

