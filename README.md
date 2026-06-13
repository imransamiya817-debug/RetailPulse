# RetailPulse — Supply Chain & Retail Analytics

> End-to-end analytics on 293,569 order records ($80.9M revenue) across three real-world datasets — diagnosing a simultaneous 14% stockout and 22% overstock problem costing GlobalMart ₹7 crore monthly.

**Author:** Samiya Imran &nbsp;|&nbsp; **Tools:** Python · Pandas · NumPy · Matplotlib · SQL Server · Tableau

---

## The Business Problem

GlobalMart faces a paradox: shelves run empty on fast-movers while warehouses overflow with slow ones. Both failures share the same root — poor visibility into delivery performance, category-level margins, and customer sentiment across three disconnected data sources.

This project ingests and cleans all three sources, builds a unified star schema, and surfaces the patterns behind the failures with actionable recommendations.

---

## Key Findings

| # | Finding | Detail |
|---|---|---|
| 1 | **Late delivery crisis** | DataCo's late delivery rate is **54.8%** (98,977 orders) — nearly 8× Olist's 7.3%. When Olist delivers early, it arrives **13.2 days ahead** of estimate on average. |
| 2 | **Revenue collapse** | DataCo monthly revenue fell **71%** from $1.14M (Sept 2017) to $0.33M (Jan 2018) — requires root cause investigation. |
| 3 | **Margin trap** | Storage drives **35% of hardware revenue ($10.7M)** but at only **0.55% margin**. RAM earns the highest margin at 3.52% but contributes the least volume. |
| 4 | **Review polarisation** | **11,424 one-star reviews (11.5%)** vs 57,328 five-star — a bimodal pattern driven by delivery experience. Avg seller response time: 75.6 hours. |
| 5 | **Regional bottleneck** | North America generates 58% of hardware revenue; South America has a disproportionately high pending-order rate signalling fulfillment bottlenecks. |

---

## Recommendations

| Priority | Action | Expected Impact |
|---|---|---|
| 🔴 Critical | Audit DataCo late delivery root cause by shipping mode | Reduce 54.8% late rate to under 20% in 2 quarters |
| 🔴 Critical | Investigate 2017–18 DataCo revenue decline | Recover or explain $800K/month gap |
| 🟡 High | Bundle RAM (3.52% margin) with Storage (high volume) | Lift blended hardware margin from 0.55% toward 2%+ |
| 🟡 High | Implement 24-hour review response policy | Reduce 1-star reviews by est. 20–30% |
| 🟢 Medium | Cap pending orders at 48 hrs in South America | Reduce cancellation risk in that region |

---

## Datasets

### Raw Data (11 source files — all included in `RetailPulseDataset/`)

| File | Source | Rows | Covers |
|---|---|---|---|
| `ML-Dataset.csv` | Kaggle | 400 | Hardware orders across 9 global warehouses |
| `DataCoSupplyChainDataset.csv` | Kaggle | 180,519 | Global retail orders with shipping & delivery data |
| `olist_orders_dataset.csv` | Kaggle | 99,441 | Brazilian marketplace order headers |
| `olist_order_items_dataset.csv` | Kaggle | — | Line items per order |
| `olist_customers_dataset.csv` | Kaggle | — | Customer records |
| `olist_products_dataset.csv` | Kaggle | — | Product catalog |
| `olist_sellers_dataset.csv` | Kaggle | — | Seller records |
| `olist_order_reviews_dataset.csv` | Kaggle | — | Customer reviews |
| `olist_order_payments_dataset.csv` | Kaggle | — | Payment records |
| `olist_geolocation_dataset.csv` | Kaggle | — | Zip-level lat/lng |
| `product_category_name_translation.csv` | Kaggle | — | Portuguese → English category names |

### Cleaned Output — Star Schema (9 tables, all included)

**Dimension tables**

| Table | Rows | Description |
|---|---|---|
| `dim_warehouse.csv` | 9 | 9 warehouses across 6 countries (from ML-Dataset) |
| `dim_employee.csv` | 400 | Employees with warehouse assignment and tenure |
| `dim_product.csv` | 33,344 | Full product catalog unified across all 3 datasets |
| `dim_customer.csv` | 120,493 | Global customers with segments and coordinates |
| `dim_seller.csv` | 3,095 | Brazilian marketplace sellers with geolocation |

**Fact tables**

| Table | Rows | Description |
|---|---|---|
| `fact_orders.csv` | 294,344 | All order lines — revenue, profit, shipping mode, risk flags |
| `fact_delivery.csv` | 279,960 | Delivery timing, delay days, late flag, delivery status |
| `fact_payments.csv` | 103,886 | Payment type, installments, and value per order |
| `fact_reviews.csv` | 98,410 | Review scores, sentiment labels, and seller response time |

---

## Data Quality Issues Fixed

**ML-Dataset**
- `RegionName` had double spaces → stripped and normalised
- `WarehouseName` had typo `"New Jersy"` → corrected to `"New Jersey"`
- Dates stored as strings `'17-Nov-16'` → parsed to datetime
- No revenue or margin columns → engineered from unit price × quantity
- Zero-quantity rows flagged as anomalies
- Product specs (`Speed`, `Cores`, `TDP`) parsed from free-text description

**DataCo**
- Dates stored as strings → parsed to datetime
- `Customer Password` column removed
- Order Status values normalised to title case
- Revenue, profit, margin, late-delivery flag, and time columns engineered

**Olist**
- 5 date columns parsed from strings to datetime
- Order status normalised
- Delivery metrics engineered: `days_actual`, `days_estimated`, `delay_days`, `is_late`
- Reviews scored into `Negative / Neutral / Positive` sentiment labels
- Response time calculated in hours
- Geolocation averaged to one lat/lng per zip code prefix
- Product names translated from Portuguese to English via category translation file

---

## Project Structure

```
RetailPulse/
├── RetailPulseDataset/          # 11 raw source files (all included)
├── RetailPulse.ipynb            # Main analysis notebook (5 sections)
├── ReatailPulse_SQL.sql         # Full SQL Server script (see below)
├── dim_customer.csv             # }
├── dim_employee.csv             # }
├── dim_product.csv              # }  Cleaned star schema
├── dim_seller.csv               # }  output tables
├── dim_warehouse.csv            # }
├── fact_delivery.csv            # }
├── fact_orders.csv              # }
├── fact_payments.csv            # }
└── fact_reviews.csv             # }
```

---

## Notebook Structure

| Section | What it covers |
|---|---|
| 1 — Data Preparation | Loading, cleaning, and integrating all 3 sources into the 9-table star schema |
| 2 — Exploratory Data Analysis | Distributions, delivery patterns, category breakdown, regional splits |
| 3 — KPI Analysis | 6 KPI tables: revenue summary, delivery performance, hardware margins, shipping mode, customer satisfaction, payment analysis |
| 4 — Business Insights & Recommendations | 5 findings with root cause reasoning and prioritised actions |
| 5 — SQL Showcase | Star schema DDL and analytical queries mirroring the Python analysis |

---

## SQL File (`ReatailPulse_SQL.sql`)

Targets **SQL Server (SSMS)**. Creates `RetailpulseDB` and contains:

| Section | Contents |
|---|---|
| 1 — DDL | Creates all 9 tables with data types, primary keys, and foreign keys |
| 2 — BULK INSERT | Loads all 9 cleaned CSVs into SQL Server |
| 3 — Views (6) | `vw_executive_kpi`, `vw_product_performance`, `vw_delivery_performance`, `vw_customer_satisfaction`, `vw_payment_analysis`, `vw_warehouse_performance` — pre-built for Tableau |
| 4 — Basic KPI Queries | Q1–Q6: Revenue summary, trends, late delivery rate, category breakdown, order status, review distribution |
| 5 — Intermediate Analysis | Q7–Q12: Shipping mode vs late rate, market revenue, hardware profitability, warehouse comparison, employee performance, payment analysis |
| 6 — Advanced SQL | Q13–Q19: ABC classification (CTE + window functions), MoM growth (LAG), delivery delay ranking (RANK), running totals (SUM OVER), top customers, review vs delivery correlation (3-table join), seller scorecard |
| 7 — Stakeholder Reports | Dedicated query blocks for VP Supply Chain, Warehouse Manager, Procurement Team, Finance Team |
| 8 — Data Quality Checks | 6 checks: row counts, null validation, FK orphan detection, duplicate check, revenue anomaly flags, date range validation |

---

## How to Run

```bash
# 1. Clone the repo
git clone https://github.com/imransamiya817-debug/RetailPulse.git
cd RetailPulse

# 2. Open and run the notebook — all raw files are already in RetailPulseDataset/
jupyter notebook RetailPulse.ipynb

# 3. Cleaned star schema tables are already in the repo root
#    Load them into SQL Server:
#    - Open ReatailPulse_SQL.sql in SSMS
#    - Update the file paths in the BULK INSERT section to match your local path
#    - Run the full script
```

---

## Tech Stack

| Layer | Tools |
|---|---|
| Data wrangling | Python · Pandas · NumPy |
| Visualisation | Matplotlib |
| Database | SQL Server · SSMS |
| BI | Tableau |
