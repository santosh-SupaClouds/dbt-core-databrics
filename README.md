# Teradata to Databricks Migration using dbt

This project facilitates the migration of data and analytics from Teradata to Databricks using dbt (data build tool).

## Overview

The migration process involves:

1. **Extract**: Retrieving data from Teradata
2. **Transform**: Using dbt to transform and model the data
3. **Load**: Moving the transformed data to Databricks
4. **Validate**: Ensuring data integrity across environments

## Project Structure and File Descriptions

```
teradata_to_databricks/
├── .dbt/                    # dbt configuration
│   └── profiles.yml         # Connection profiles for Teradata and Databricks
├── .github/                 # CI/CD configuration
│   └── workflows/
│       └── dbt_migration.yml # GitHub Actions workflow for automated testing and deployment
├── analyses/                # Ad-hoc analyses
│   └── data_quality_check.sql # SQL to compare record counts between environments
├── macros/                  # Reusable code blocks
│   ├── data_type_conversion.sql # Handles data type differences between platforms
│   ├── generate_schema_name.sql # Customizes schema naming for different environments
│   └── teradata_utils.sql   # Utilities for working with Teradata schemas and tables
├── models/                  # dbt models organized in layers
│   ├── marts/               # Business-ready models
│   │   ├── core/            # Core business entities
│   │   │   ├── dim_customers.sql # Customer dimension table
│   │   │   ├── dim_products.sql  # Product dimension table
│   │   │   ├── fact_orders.sql   # Order fact table
│   │   │   └── schema.yml        # Documentation and tests for core models
│   │   └── marketing/        # Marketing-specific models
│   │       ├── customer_sales_summary.sql # Period-based customer sales analysis
│   │       └── schema.yml    # Documentation and tests for marketing models
│   ├── intermediate/        # Intermediate models
│   │   ├── int_customer_orders.sql # Customer order aggregations
│   │   └── schema.yml       # Documentation and tests for intermediate models
│   ├── staging/             # Source-aligned models
│   │   ├── stg_teradata__customers.sql # Standardized customer data
│   │   ├── stg_teradata__orders.sql    # Standardized order data
│   │   ├── stg_teradata__products.sql  # Standardized product data
│   │   └── schema.yml       # Documentation and tests for staging models
│   └── sources.yml          # Source definitions connecting to Teradata tables
├── seeds/                   # Static reference data
│   ├── region_mapping.csv   # Mapping of region codes to region names
│   └── product_category_mapping.csv # Mapping of category IDs to names and departments
├── snapshots/               # Point-in-time snapshots
│   └── customer_snapshot.sql # SCD Type 2 snapshot of customer data
├── tests/                   # Data tests
│   ├── generic/
│   │   └── test_not_null_proportion.sql # Tests for column non-null percentages
│   └── singular/
│       ├── test_email_format.sql       # Validates email address format
│       └── test_order_total_check.sql  # Validates positive order totals
├── scripts/                 # Helper scripts
│   └── compare_environments.py # Python script to compare data between environments
├── dbt_project.yml          # Main dbt project configuration
├── packages.yml             # External dbt package dependencies
├── requirements.txt         # Python dependencies
├── setup.sh                 # Bash setup script for automated migration
├── Makefile                 # Make targets for simplified command execution
├── .gitignore               # Git ignore patterns
└── README.md                # Project documentation
```

### Key Files and Their Purpose

#### Configuration Files
- **dbt_project.yml**: The main configuration file for the dbt project, specifying model materialization strategies, directory configurations, and project variables.
- **profiles.yml**: Contains connection details for both Teradata and Databricks environments.
- **packages.yml**: Lists external dbt packages used in the project, including dbt_utils and dbt_expectations.

#### Source Mapping
- **models/sources.yml**: Maps Teradata source tables to dbt sources, including column definitions, tests, and documentation.

#### Model Layers
1. **Staging Models**:
   - First layer of transformation that standardizes data from source tables
   - Handles type conversions, renames columns to a consistent format
   - Examples: `stg_teradata__customers.sql`, `stg_teradata__orders.sql`

2. **Intermediate Models**:
   - Contains business logic that spans multiple staging models
   - Not meant for direct consumption by end users
   - Example: `int_customer_orders.sql` joins customer and order data

3. **Mart Models**:
   - Final layer of transformation that produces business-ready data
   - Organized into subject areas like "core" and "marketing"
   - Examples: `dim_customers.sql`, `fact_orders.sql`, `customer_sales_summary.sql`

#### Utility Macros
- **data_type_conversion.sql**: Contains `convert_teradata_to_databricks_type()` macro for handling data type conversions between platforms.
- **generate_schema_name.sql**: Customizes schema name generation based on the target platform.
- **teradata_utils.sql**: Includes utilities for extracting Teradata metadata like tables, columns, and primary keys.

#### Testing Framework
- **tests/generic/test_not_null_proportion.sql**: Tests that a minimum proportion of rows have non-null values.
- **tests/singular/test_email_format.sql**: Validates that email addresses follow a valid format.
- **tests/singular/test_order_total_check.sql**: Ensures that order totals are positive for non-cancelled orders.

#### Reference Data
- **seeds/region_mapping.csv**: Lookup table that maps region codes to human-readable region names.
- **seeds/product_category_mapping.csv**: Lookup table for product category details.

#### Automation
- **setup.sh**: Shell script that automates the full migration process from Teradata to Databricks.
- **Makefile**: Provides make targets for common operations and simplified command execution.
- **.github/workflows/dbt_migration.yml**: GitHub Actions workflow that tests, deploys, and compares environments.

#### Comparison and Validation
- **analyses/data_quality_check.sql**: SQL query that compares record counts between environments.
- **scripts/compare_environments.py**: Python script that verifies data integrity across platforms.


## Prerequisites

- Python 3.9+
- Access to a Teradata instance
- Access to a Databricks workspace
- Required credentials for both platforms

## Environment Variables

Set the following environment variables before running:

### Teradata Configuration:
```bash
export TERADATA_HOST='your_teradata_host'
export TERADATA_USERNAME='migration_user'
export DBT_TERADATA_PASSWORD='your_secure_password'
export TERADATA_DATABASE='your_teradata_database'
export TERADATA_SCHEMA='your_teradata_schema'
```

### Databricks Configuration:
```bash
export DATABRICKS_HOST='your_databricks_host'
export DATABRICKS_HTTP_PATH='/sql/protocolv1/o/0123456789/0123456789'
export DBT_DATABRICKS_TOKEN='your_databricks_token'
export DATABRICKS_CATALOG='teradata_migration'
export DATABRICKS_SCHEMA='transformed_data'
```

## Setup Instructions

1. Clone this repository:
   ```bash
   git clone https://github.com/your-org/teradata_to_databricks.git
   cd teradata_to_databricks
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   dbt deps
   ```

3. Run the automated setup script:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

## Command Summary

### Initial Setup with VS Code

```bash
# Create project structure
mkdir -p teradata_to_databricks
cd teradata_to_databricks

# Clone the repository if using version control
git clone https://github.com/your-org/teradata_to_databricks.git .
# OR initialize a new git repository
git init

# Open the project in VS Code
code .

# Setup Python environment with VS Code
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Install dbt-teradata from GitHub (not available in PyPI)
pip install git+https://github.com/Teradata/dbt-teradata.git

# Install dbt dependencies
dbt deps

# Create .env file for credentials (VS Code can load these with Python extension)
cat > .env << EOL
TERADATA_HOST=your_teradata_host
TERADATA_USERNAME=migration_user
DBT_TERADATA_PASSWORD=your_secure_password
TERADATA_DATABASE=your_teradata_database
TERADATA_SCHEMA=your_teradata_schema
DATABRICKS_HOST=your_databricks_host
DATABRICKS_HTTP_PATH=/sql/protocolv1/o/0123456789/0123456789
DBT_DATABRICKS_TOKEN=your_databricks_token
DATABRICKS_CATALOG=teradata_migration
DATABRICKS_SCHEMA=transformed_data
EOL

# Install VS Code extensions (optional)
code --install-extension ms-python.python
code --install-extension innoverio.vscode-dbt-power-user
code --install-extension ms-python.vscode-pylance
code --install-extension redhat.vscode-yaml
code --install-extension xyz.local-history
```

#### VS Code Configuration

Create a VS Code workspace configuration file:

```bash
mkdir -p .vscode
cat > .vscode/settings.json << EOL
{
    "python.defaultInterpreterPath": ".venv/bin/python",
    "python.terminal.activateEnvironment": true,
    "editor.formatOnSave": true,
    "editor.rulers": [88],
    "python.linting.enabled": true,
    "python.linting.flake8Enabled": true,
    "python.formatting.provider": "black",
    "python.envFile": "\${workspaceFolder}/.env",
    "terminal.integrated.env.linux": {
        "PYTHONPATH": "\${workspaceFolder}"
    },
    "terminal.integrated.env.osx": {
        "PYTHONPATH": "\${workspaceFolder}"
    },
    "terminal.integrated.env.windows": {
        "PYTHONPATH": "\${workspaceFolder}"
    },
    "[sql]": {
        "editor.formatOnSave": false
    },
    "[python]": {
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
            "source.organizeImports": true
        }
    },
    "files.associations": {
        "**/*.sql": "jinja-sql",
        "**/*.yml": "yaml",
        "**/*.yaml": "yaml"
    }
}
EOL

# Load environment variables in your terminal session
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi
```

### Teradata Steps

Run bash script `teradata_setup.sh`:

```bash
# Make the script executable
chmod +x teradata_setup.sh

# Run the script
./teradata_setup.sh
```

### Databricks Steps

Run a bash script `databricks_setup.sh`:

```bash

# Make the script executable
chmod +x databricks_setup.sh

# Run the script
./databricks_setup.sh
```

### Verification Steps

# Make the script executable
```bash
chmod +x verify_migration.sh

# Run the script
./verify_migration.sh
```

## Manual Execution

### Testing Connections:
```bash
dbt debug --target teradata
dbt debug --target databricks
```

### Running Against Teradata:
```bash
dbt seed --target teradata
dbt run --target teradata
dbt test --target teradata
```

### Running Against Databricks:
```bash
dbt seed --target databricks
dbt run --target databricks
dbt test --target databricks
```

### Comparing Environments:
```bash
python scripts/compare_environments.py
```

## CI/CD Pipeline

This project includes a GitHub Actions workflow that:

1. Tests against Teradata
2. Deploys to Databricks
3. Compares data between environments

## Customization

To adapt this project for your own data:

1. Update `models/sources.yml` with your Teradata tables
2. Modify the staging models to match your source data structure
3. Customize the intermediate and mart models for your analytics requirements
4. Update seed files with your reference data

## Best Practices

- Always test changes in Teradata before deploying to Databricks
- Use snapshots for tables that change frequently
- Leverage dbt tests to ensure data quality
- Document your models using the schema.yml files

## Troubleshooting

### Common Issues:

1. **Connection Problems**:
   - Verify network connectivity to both environments
   - Confirm credentials are correct
   - Check VPN/firewall settings

2. **Data Type Mismatches**:
   - Use the data_type_conversion macro to handle type differences
   - Add explicit casting in your models

3. **Performance Issues**:
   - Add appropriate clustering/partitioning in Databricks
   - Use incremental models for large tables

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- dbt Labs for the amazing data transformation tool
- The Teradata and Databricks communities for their documentation and support