#!/usr/bin/env python
"""
Script to compare table counts between Teradata and Databricks environments
Used in the migration process to verify data integrity
"""

import os
import pandas as pd
from tabulate import tabulate

def main():
    """Compare record counts between Teradata and Databricks environments."""
    # Read CSV files with counts from each environment
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
    
    # Print results
    print("\n=== RECORD COUNT COMPARISON: TERADATA VS DATABRICKS ===\n")
    print(tabulate(
        comparison_df[[
            'table_name', 
            'record_count_teradata', 
            'record_count_databricks',
            'count_diff',
            'diff_percentage',
            'status'
        ]],
        headers=[
            'Table', 
            'Teradata Count', 
            'Databricks Count',
            'Difference',
            'Diff %',
            'Status'
        ],
        tablefmt='pretty'
    ))
    
    # Check if there are any failures
    failures = comparison_df[comparison_df['status'] == 'FAIL']
    if not failures.empty:
        print(f"\n⚠️ WARNING: Found {len(failures)} tables with count mismatches!\n")
        failed_tables = ", ".join(failures['table_name'].tolist())
        print(f"Failed tables: {failed_tables}")
        exit(1)
    else:
        print("\n✅ SUCCESS: All table counts match between environments!\n")
        exit(0)

if __name__ == "__main__":
    main()
