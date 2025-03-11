#!/bin/bash
# Setup script for Teradata to Databricks migration
set -e

# Print with colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Teradata to Databricks Migration Setup ===${NC}"

# Check required environment variables
check_env_var() {
    if [ -z "${!1}" ]; then
        echo -e "${RED}Error: ${1} environment variable is not set${NC}"
        exit 1
    fi
}

# Teradata variables
echo -e "${YELLOW}Checking Teradata configuration...${NC}"
check_env_var "TERADATA_HOST"
check_env_var "TERADATA_USERNAME"
check_env_var "DBT_TERADATA_PASSWORD"
check_env_var "TERADATA_DATABASE"
check_env_var "TERADATA_SCHEMA"

# Databricks variables
echo -e "${YELLOW}Checking Databricks configuration...${NC}"
check_env_var "DATABRICKS_HOST"
check_env_var "DATABRICKS_HTTP_PATH"
check_env_var "DBT_DATABRICKS_TOKEN"
check_env_var "DATABRICKS_CATALOG"
check_env_var "DATABRICKS_SCHEMA"

# Check required tools
echo -e "${YELLOW}Checking required tools...${NC}"

if ! command -v python &> /dev/null; then
    echo -e "${RED}Error: Python is not installed${NC}"
    exit 1
fi

if ! command -v pip &> /dev/null; then
    echo -e "${RED}Error: pip is not installed${NC}"
    exit 1
fi

if ! command -v dbt &> /dev/null; then
    echo -e "${YELLOW}Installing dbt...${NC}"
    pip install dbt-core dbt-teradata dbt-databricks
fi

# Install dependencies
echo -e "${YELLOW}Installing project dependencies...${NC}"
pip install -r requirements.txt
dbt deps

# Create necessary directories
echo -e "${YELLOW}Creating necessary directories...${NC}"
mkdir -p data logs

# Run against Teradata
echo -e "${YELLOW}=== Running against Teradata ===${NC}"
echo -e "${YELLOW}1. Testing connection to Teradata...${NC}"
dbt debug --target teradata

echo -e "${YELLOW}2. Loading seed data to Teradata...${NC}"
dbt seed --target teradata

echo -e "${YELLOW}3. Running models in Teradata...${NC}"
dbt run --target teradata

echo -e "${YELLOW}4. Testing models in Teradata...${NC}"
dbt test --target teradata

echo -e "${YELLOW}5. Generating documentation for Teradata...${NC}"
dbt docs generate --target teradata

# Run against Databricks
echo -e "${YELLOW}=== Running against Databricks ===${NC}"
echo -e "${YELLOW}1. Testing connection to Databricks...${NC}"
dbt debug --target databricks

echo -e "${YELLOW}2. Loading seed data to Databricks...${NC}"
dbt seed --target databricks

echo -e "${YELLOW}3. Running models in Databricks...${NC}"
dbt run --target databricks

echo -e "${YELLOW}4. Testing models in Databricks...${NC}"
dbt test --target databricks

echo -e "${YELLOW}5. Generating documentation for Databricks...${NC}"
dbt docs generate --target databricks

# Compare environments
echo -e "${YELLOW}=== Comparing environments ===${NC}"
echo -e "${YELLOW}1. Running data quality check in Teradata...${NC}"
dbt run-operation run_query --args '{query: "{% include \"./analyses/data_quality_check.sql\" %}", target: teradata, output: "data/teradata_counts.csv"}'

echo -e "${YELLOW}2. Running data quality check in Databricks...${NC}"
dbt run-operation run_query --args '{query: "{% include \"./analyses/data_quality_check.sql\" %}", target: databricks, output: "data/databricks_counts.csv"}'

echo -e "${YELLOW}3. Comparing count results...${NC}"
python scripts/compare_environments.py

echo -e "${GREEN}=== Migration setup completed successfully ===${NC}"
echo -e "${GREEN}To view documentation, run: dbt docs serve${NC}"
