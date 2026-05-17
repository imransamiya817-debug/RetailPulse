# RetailPulse — Supply Chain & Retail Analytics

## Status: In Progress 🔄

## Business Problem
GlobalMart is losing ₹7 crore monthly from simultaneous
14% stockout and 22% overstock rates. This project analyses
293,569 order records totalling $80.9M revenue across 3 datasets.

## Tools
Python · Pandas · NumPy · Matplotlib · SQL Server · Tableau

## Key Findings
- DataCo late delivery rate: 54.8% vs Olist 7.3%
- Storage drives 35% hardware revenue at only 0.55% margin
- 11,424 one-star reviews linked to late deliveries

## Datasets
9 files included in Raw_Data Folder
2 large files — download from Kaggle:
- DataCo: https://www.kaggle.com/datasets/shashwatwork/dataco-smart-supply-chain-for-big-data-analysis
- Olist geolocation: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

Place both in data/raw/ before running the notebook.

## How to Run
1. Clone this repo
2. Download 2 large files from Kaggle links above
3. Run notebooks/RetailPulse_Analysis.ipynb top to bottom
4. Clean tables auto-save to clean named folder
5. Load into SQL Server using sql/RetailPulse_SQL.sql
