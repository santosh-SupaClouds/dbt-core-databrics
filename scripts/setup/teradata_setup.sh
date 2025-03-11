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
