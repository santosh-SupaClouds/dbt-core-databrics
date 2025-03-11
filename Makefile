# Makefile for Teradata to Databricks Migration

.PHONY: help setup install deps env-check teradata-check databricks-check
.PHONY: teradata-seed teradata-run teradata-test teradata-docs
.PHONY: databricks-seed databricks-run databricks-test databricks-docs
.PHONY: compare clean all

# Default target
help:
	@echo "Teradata to Databricks Migration Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  help                 Show this help message"
	@echo "  setup                Run complete setup and migration"
	@echo "  install              Install required dependencies"
	@echo "  deps                 Install dbt dependencies"
	@echo "  env-check            Check required environment variables"
	@echo "  teradata-check       Test connection to Teradata"
	@echo "  teradata-seed        Load seed data to Teradata"
	@echo "  teradata-run         Run models in Teradata"
	@echo "  teradata-test        Test models in Teradata"
	@echo "  teradata-docs        Generate documentation for Teradata"
	@echo "  databricks-check     Test connection to Databricks"
	@echo "  databricks-seed      Load seed data to Databricks"
	@echo "  databricks-run       Run models in Databricks"
	@echo "  databricks-test      Test models in Databricks"
	@echo "  databricks-docs      Generate documentation for Databricks"
	@echo "  compare              Compare environments"
	@echo "  clean                Clean generated files"
	@echo "  all                  Run all steps (full migration)"
	@echo ""
	@echo "Example: make setup"

# Complete setup
setup: install deps env-check

# Install required dependencies
install:
	@echo "Installing required dependencies..."
	pip install -r requirements.txt

# Install dbt dependencies
deps:
	@echo "Installing dbt dependencies..."
	dbt deps

# Check environment variables
env-check:
	@echo "Checking environment variables..."
	@if [ -z "$$TERADATA_HOST" ]; then echo "Error: TERADATA_HOST is not set"; exit 1; fi
	@if [ -z "$$TERADATA_USERNAME" ]; then echo "Error: TERADATA_USERNAME is not set"; exit 1; fi
	@if [ -z "$$DBT_TERADATA_PASSWORD" ]; then echo "Error: DBT_TERADATA_PASSWORD is not set"; exit 1; fi
	@if [ -z "$$TERADATA_DATABASE" ]; then echo "Error: TERADATA_DATABASE is not set"; exit 1; fi
	@if [ -z "$$TERADATA_SCHEMA" ]; then echo "Error: TERADATA_SCHEMA is not set"; exit 1; fi
	@if [ -z "$$DATABRICKS_HOST" ]; then echo "Error: DATABRICKS_HOST is not set"; exit 1; fi
	@if [ -z "$$DATABRICKS_HTTP_PATH" ]; then echo "Error: DATABRICKS_HTTP_PATH is not set"; exit 1; fi
	@if [ -z "$$DBT_DATABRICKS_TOKEN" ]; then echo "Error: DBT_DATABRICKS_TOKEN is not set"; exit 1; fi
	@if [ -z "$$DATABRICKS_CATALOG" ]; then echo "Error: DATABRICKS_CATALOG is not set"; exit 1; fi
	@if [ -z "$$DATABRICKS_SCHEMA" ]; then echo "Error: DATABRICKS_SCHEMA is not set"; exit 1; fi
	@echo "All environment variables are set"

# Teradata operations
teradata-check:
	@echo "Testing connection to Teradata..."
	dbt debug --target teradata

teradata-seed: teradata-check
	@echo "Loading seed data to Teradata..."
	dbt seed --target teradata

teradata-run: teradata-check
	@echo "Running models in Teradata..."
	dbt run --target teradata

teradata-test: teradata-run
	@echo "Testing models in Teradata..."
	dbt test --target teradata

teradata-docs: teradata-run
	@echo "Generating documentation for Teradata..."
	dbt docs generate --target teradata

teradata-all: teradata-seed teradata-run teradata-test teradata-docs
	@echo "Completed all Teradata operations"

# Databricks operations
databricks-check:
	@echo "Testing connection to Databricks..."
	dbt debug --target databricks

databricks-seed: databricks-check
	@echo "Loading seed data to Databricks..."
	dbt seed --target databricks

databricks-run: databricks-check
	@echo "Running models in Databricks..."
	dbt run --target databricks

databricks-test: databricks-run
	@echo "Testing models in Databricks..."
	dbt test --target databricks

databricks-docs: databricks-run
	@echo "Generating documentation for Databricks..."
	dbt docs generate --target databricks

databricks-all: databricks-seed databricks-run databricks-test databricks-docs
	@echo "Completed all Databricks operations"

# Compare environments
compare: teradata-run databricks-run
	@echo "Comparing environments..."
	@mkdir -p data
	dbt run-operation run_query --args '{query: "{% include \"./analyses/data_quality_check.sql\" %}", target: teradata, output: "data/teradata_counts.csv"}'
	dbt run-operation run_query --args '{query: "{% include \"./analyses/data_quality_check.sql\" %}", target: databricks, output: "data/databricks_counts.csv"}'
	python scripts/compare_environments.py

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	rm -rf target
	rm -rf logs
	rm -rf dbt_packages
	rm -rf .pytest_cache
	rm -rf data/*.csv
	@echo "Clean completed"

# Run all steps
all: setup teradata-all databricks-all compare
	@echo "Migration completed successfully"
