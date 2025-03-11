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
