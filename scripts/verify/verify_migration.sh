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
