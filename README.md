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

Create a bash script `teradata_setup.sh`:

```bash
cat > teradata_setup.sh << 'EOL'
#!/bin/bash
# Teradata setup and migration script

# Set error handling
set -e

# Load environment variables if not already set
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Create logs directory
mkdir -p logs

# Log start
echo "$(date): Starting Teradata setup" | tee logs/teradata_setup.log

# Step 1: Test Teradata connection
echo "Testing Teradata connection..."
dbt debug --target teradata | tee -a logs/teradata_setup.log

# Step 2: Create Teradata database objects if needed
echo "Creating Teradata database objects..."
cat > temp_teradata_script.bteq << EOF
.LOGON ${TERADATA_HOST}/${TERADATA_USERNAME},${DBT_TERADATA_PASSWORD}
DATABASE ${TERADATA_DATABASE};

-- Drop tables if they exist (optional, comment out if not needed)
DROP TABLE ${TERADATA_SCHEMA}.customers;
DROP TABLE ${TERADATA_SCHEMA}.orders;
DROP TABLE ${TERADATA_SCHEMA}.products;

-- Create tables
CREATE TABLE ${TERADATA_SCHEMA}.customers (
    customer_id INTEGER NOT NULL,
    customer_name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(200),
    city VARCHAR(50),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    country VARCHAR(50),
    region_code VARCHAR(10),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE ${TERADATA_SCHEMA}.orders (
    order_id INTEGER NOT NULL,
    customer_id INTEGER NOT NULL,
    order_date DATE,
    order_status VARCHAR(20),
    order_total DECIMAL(10,2),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE ${TERADATA_SCHEMA}.products (
    product_id INTEGER NOT NULL,
    product_name VARCHAR(100),
    description VARCHAR(500),
    price DECIMAL(10,2),
    category_id INTEGER,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Insert sample data (optional)
INSERT INTO ${TERADATA_SCHEMA}.customers VALUES
(1, 'John Doe', 'john@example.com', '555-1234', '123 Main St', 'New York', 'NY', '10001', 'USA', 'E', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(2, 'Jane Smith', 'jane@example.com', '555-5678', '456 Oak Ave', 'Los Angeles', 'CA', '90001', 'USA', 'W', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO ${TERADATA_SCHEMA}.products VALUES
(1, 'Laptop', 'High-performance laptop', 1200.00, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(2, 'Smartphone', 'Latest smartphone', 800.00, 3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO ${TERADATA_SCHEMA}.orders VALUES
(1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'delivered', 1200.00, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(2, 2, CURRENT_DATE - INTERVAL '15' DAY, 'shipped', 800.00, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

.LOGOFF
EOF

if command -v bteq &> /dev/null; then
    bteq < temp_teradata_script.bteq > logs/teradata_tables.log 2>&1
    echo "Teradata database objects created successfully"
else
    echo "WARNING: bteq command not found. Tables will need to be created manually."
    echo "See temp_teradata_script.bteq for the SQL commands to execute"
fi

# Step 3: Seed reference data
echo "Loading seed data to Teradata..."
dbt seed --target teradata | tee -a logs/teradata_setup.log

# Step 4: Run dbt models
echo "Running models in Teradata..."
dbt run --target teradata | tee -a logs/teradata_setup.log

# Step 5: Run tests
echo "Testing models in Teradata..."
dbt test --target teradata | tee -a logs/teradata_setup.log

# Step 6: Generate documentation
echo "Generating documentation for Teradata..."
dbt docs generate --target teradata | tee -a logs/teradata_setup.log

# Step 7: Serve documentation (background process)
echo "Starting documentation server in background..."
dbt docs serve --port 8080 > logs/docs_server.log 2>&1 &
echo "Documentation server started on http://localhost:8080"

# Cleanup
rm -f temp_teradata_script.bteq

echo "$(date): Teradata setup completed successfully" | tee -a logs/teradata_setup.log
echo "View detailed logs in logs/teradata_setup.log"
EOL

# Make the script executable
chmod +x teradata_setup.sh

# Run the script
./teradata_setup.sh
```

### Databricks Steps

Create a bash script `databricks_setup.sh`:

```bash
cat > databricks_setup.sh << 'EOL'
#!/bin/bash
# Databricks setup and migration script

# Set error handling
set -e

# Load environment variables if not already set
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Create logs directory
mkdir -p logs

# Log start
echo "$(date): Starting Databricks setup" | tee logs/databricks_setup.log

# Step 1: Test Databricks connection
echo "Testing Databricks connection..."
dbt debug --target databricks | tee -a logs/databricks_setup.log

# Step 2: Set up Databricks catalog and schemas
echo "Setting up Databricks catalog and schemas..."

# Create SQL script for Databricks
cat > databricks_init.sql << EOF
CREATE CATALOG IF NOT EXISTS ${DATABRICKS_CATALOG};
USE CATALOG ${DATABRICKS_CATALOG};
CREATE SCHEMA IF NOT EXISTS raw_data;
CREATE SCHEMA IF NOT EXISTS transformed_data;
CREATE SCHEMA IF NOT EXISTS reference_data;
CREATE SCHEMA IF NOT EXISTS snapshots;

-- Grant permissions (modify as needed)
GRANT CREATE, USAGE ON CATALOG ${DATABRICKS_CATALOG} TO \`account users\`;
GRANT CREATE, USAGE ON SCHEMA ${DATABRICKS_CATALOG}.raw_data TO \`account users\`;
GRANT CREATE, USAGE ON SCHEMA ${DATABRICKS_CATALOG}.transformed_data TO \`account users\`;
GRANT CREATE, USAGE ON SCHEMA ${DATABRICKS_CATALOG}.reference_data TO \`account users\`;
GRANT CREATE, USAGE ON SCHEMA ${DATABRICKS_CATALOG}.snapshots TO \`account users\`;
EOF

# Check if Databricks CLI is installed
if command -v databricks &> /dev/null; then
    # Set up Databricks CLI config if not already configured
    if [ ! -f ~/.databrickscfg ]; then
        echo "Configuring Databricks CLI..."
        cat > ~/.databrickscfg << DBCFG
[DEFAULT]
host = ${DATABRICKS_HOST}
token = ${DBT_DATABRICKS_TOKEN}
DBCFG
    fi

    # Execute SQL using Databricks CLI
    echo "Creating Databricks catalog and schemas..."
    databricks fs mkdirs dbfs:/FileStore/migration/
    databricks fs cp databricks_init.sql dbfs:/FileStore/migration/databricks_init.sql
    
    # Run the SQL commands
    # Note: This requires Databricks SQL CLI or REST API. Simplified example:
    echo "NOTE: You will need to manually run the SQL commands in databricks_init.sql"
    echo "through the Databricks UI or CLI."
else
    echo "WARNING: databricks CLI not found. Manual setup required."
    echo "Please run the SQL commands in databricks_init.sql in your Databricks workspace."
fi

# Step 3: Seed reference data
echo "Loading seed data to Databricks..."
dbt seed --target databricks | tee -a logs/databricks_setup.log

# Step 4: Run dbt models
echo "Running models in Databricks..."
dbt run --target databricks | tee -a logs/databricks_setup.log

# Step 5: Run tests
echo "Testing models in Databricks..."
dbt test --target databricks | tee -a logs/databricks_setup.log

# Step 6: Generate documentation
echo "Generating documentation for Databricks..."
dbt docs generate --target databricks | tee -a logs/databricks_setup.log

# Step 7: Serve documentation (background process)
echo "Starting documentation server in background..."
dbt docs serve --port 8081 > logs/docs_server_databricks.log 2>&1 &
echo "Documentation server started on http://localhost:8081"

# Cleanup
rm -f databricks_init.sql

echo "$(date): Databricks setup completed successfully" | tee -a logs/databricks_setup.log
echo "View detailed logs in logs/databricks_setup.log"
EOL

# Make the script executable
chmod +x databricks_setup.sh

# Run the script
./databricks_setup.sh
```

### Verification Steps

Create a bash script `verify_migration.sh`:

```bash
cat > verify_migration.sh << 'EOL'
#!/bin/bash
# Migration verification script

# Set error handling
set -e

# Load environment variables if not already set
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Create logs and data directories
mkdir -p logs data

# Log start
echo "$(date): Starting migration verification" | tee logs/verification.log

# Step 1: Ensure both environments are up-to-date
echo "Ensuring both environments are up-to-date..."
echo "Running dbt models in Teradata..."
dbt run --target teradata > logs/verification_teradata.log 2>&1
echo "Running dbt models in Databricks..."
dbt run --target databricks > logs/verification_databricks.log 2>&1

# Step 2: Run data quality check in Teradata
echo "Running data quality check in Teradata..."
dbt run-operation run_query --args "{query: \"{% include './analyses/data_quality_check.sql' %}\", target: teradata, output: \"data/teradata_counts.csv\"}" | tee -a logs/verification.log

# Step 3: Run data quality check in Databricks
echo "Running data quality check in Databricks..."
dbt run-operation run_query --args "{query: \"{% include './analyses/data_quality_check.sql' %}\", target: databricks, output: \"data/databricks_counts.csv\"}" | tee -a logs/verification.log

# Step 4: Compare results with Python script
echo "Comparing environment results..."
python scripts/compare_environments.py | tee -a logs/verification.log

# Check if comparison was successful
if [ $? -eq 0 ]; then
    echo "✅ VERIFICATION SUCCESSFUL: Data matches between environments!"
else
    echo "❌ VERIFICATION FAILED: Data discrepancies detected. See logs for details."
    echo "Check logs/verification.log for more information."
fi

# Generate HTML comparison report
echo "Generating HTML comparison report..."
cat > scripts/generate_report.py << 'PYEOF'
import pandas as pd
import sys
from datetime import datetime

def create_html_report():
    try:
        # Read the CSV files
        teradata_df = pd.read_csv('data/teradata_counts.csv')
        databricks_df = pd.read_csv('data/databricks_counts.csv')
        
        # Merge dataframes to compare counts
        comparison_df = pd.merge(
            teradata_df, 
            databricks_df,
            on='table_name',
            suffixes=('_teradata', '_databricks')
        )
        
        # Calculate difference and percentage
        comparison_df['count_diff'] = comparison_df['record_count_databricks'] - comparison_df['record_count_teradata']
        comparison_df['diff_percentage'] = (
            comparison_df['count_diff'] / comparison_df['record_count_teradata'] * 100
        ).fillna(0).round(2)
        
        # Add a pass/fail column
        comparison_df['status'] = comparison_df.apply(
            lambda row: 'PASS' if abs(row['diff_percentage']) < 1 else 'FAIL',
            axis=1
        )
        
        # Create HTML
        html = f"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Teradata to Databricks Migration Verification Report</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; }}
                h1 {{ color: #1a73e8; }}
                table {{ border-collapse: collapse; width: 100%; margin-top: 20px; }}
                th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
                th {{ background-color: #f2f2f2; }}
                tr:nth-child(even) {{ background-color: #f9f9f9; }}
                .pass {{ background-color: #dff0d8; color: #3c763d; }}
                .fail {{ background-color: #f2dede; color: #a94442; }}
                .summary {{ margin-top: 20px; padding: 10px; border: 1px solid #ddd; }}
                .timestamp {{ color: #666; font-size: 0.8em; }}
            </style>
        </head>
        <body>
            <h1>Teradata to Databricks Migration Verification Report</h1>
            <p class="timestamp">Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
            
            <div class="summary">
                <h2>Summary</h2>
                <p>Total tables checked: {len(comparison_df)}</p>
                <p>Passing tables: {len(comparison_df[comparison_df['status'] == 'PASS'])}</p>
                <p>Failing tables: {len(comparison_df[comparison_df['status'] == 'FAIL'])}</p>
            </div>
            
            <h2>Table Comparison Details</h2>
            <table>
                <tr>
                    <th>Table</th>
                    <th>Teradata Count</th>
                    <th>Databricks Count</th>
                    <th>Difference</th>
                    <th>Diff %</th>
                    <th>Status</th>
                </tr>
        """
        
        # Add rows
        for _, row in comparison_df.iterrows():
            status_class = "pass" if row['status'] == 'PASS' else "fail"
            html += f"""
                <tr class="{status_class}">
                    <td>{row['table_name']}</td>
                    <td>{row['record_count_teradata']}</td>
                    <td>{row['record_count_databricks']}</td>
                    <td>{row['count_diff']}</td>
                    <td>{row['diff_percentage']}%</td>
                    <td>{row['status']}</td>
                </tr>
            """
        
        html += """
            </table>
        </body>
        </html>
        """
        
        # Write HTML to file
        with open('data/verification_report.html', 'w') as f:
            f.write(html)
        
        print("HTML report generated successfully: data/verification_report.html")
        return 0
    except Exception as e:
        print(f"Error generating report: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(create_html_report())
PYEOF

# Run the report generation script
python scripts/generate_report.py | tee -a logs/verification.log

echo "$(date): Verification completed" | tee -a logs/verification.log
echo "View detailed report at data/verification_report.html"
EOL

# Make the script executable
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