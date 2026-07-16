/* =================================================================
   SECTION 1 — DATABASE & TABLE CREATION (DDL)
   ================================================================= */
-- Step 1: Create the database
-- (Skip if RetailPulseDB already exists)
IF NOT EXISTS(SELECT name FROM sys.databases WHERE name = 'RetailPulseDB')
BEGIN
	CREATE DATABASE RetailPulseDB;
	PRINT 'Database RetailPulseDB Created ';
END
GO
USE RetailPulseDB;
GO

/* =============================================
 DIMENSION TABLES (reference/lookup tables)
 ============================================= */
 
-- TABLE 1  : dim_warehouse
-- Source   : ML-Dataset.csv
-- Purpose  : 9 global warehouses across 6 countries
-- Used by  : Warehouse Manager reports, geographic KPIs

IF OBJECT_ID('dim_warehouse','U') IS NOT NULL DROP TABLE dim_warehouse;
CREATE TABLE dim_warehouse(
	warehouse_id INT PRIMARY KEY,
	warehouse_name VARCHAR(100) NOT NULL,
	warehouse_address VARCHAR(200) NULL,
	city VARCHAR(100) NULL,
	state VARCHAR(100) NULL,
	postal_code VARCHAR(20) NULL,
	region VARCHAR(100) NULL,
	country VARCHAR(100) NULL
);

-- TABLE 2  : dim_product
-- Source   : ML-Dataset + DataCo + Olist (combined)
-- Purpose  : Full product catalog — 33,344 SKUs across 3 datasets
-- Used by  : Category revenue, margin analysis, inventory health
IF OBJECT_ID('dim_product','U') IS NOT NULL DROP TABLE dim_product;
CREATE TABLE dim_product(
product_id VARCHAR(50) PRIMARY KEY,
product_name VARCHAR(300) NULL,	
category VARCHAR(200) NULL,
product_description VARCHAR(MAX)   NULL,
standard_cost DECIMAL(12,2) NULL,           -- NULL for DataCo and Olist
list_price DECIMAL(12,2) NULL,
weight_g DECIMAL(10,2) NULL,           -- NULL for ML and DataCo
length_cm DECIMAL(10,2) NULL,
height_cm DECIMAL(10,2) NULL,
width_cm DECIMAL(10,2) NULL,
photos_qty DECIMAL(10,2) NULL,
spec_speed VARCHAR(50) NULL,           -- Parsed from ML description
spec_cores VARCHAR(50) NULL,
spec_tdp VARCHAR(50) NULL,
markup_pct DECIMAL(8,2) NULL,
source_dataset VARCHAR(10)NOT NULL        -- 'ML', 'DataCo', or 'Olist'
);

-- TABLE 3  : dim_customer
-- Source   : ML-Dataset + DataCo + Olist customers + geolocation
-- Purpose  : 120,493 global customers with segments and coordinates
-- Used by  : Geographic analysis, customer segmentation, credit risk

IF OBJECT_ID ('dim_customer', 'U') IS NOT NULL DROP TABLE dim_customer;

CREATE TABLE dim_customer(
customer_id VARCHAR(100) PRIMARY KEY,    -- ML_C1, DC_C20755, or Olist UUID
customer_name VARCHAR(200) NULL,         -- NULL for Olist (privacy masked)
email VARCHAR(200) NULL,
phone VARCHAR(50) NULL,
address VARCHAR(300) NULL,
city VARCHAR(100) NULL,
state VARCHAR(100) NULL,
zip_code VARCHAR(20) NULL,
latitude DECIMAL(10,6) NULL,             -- From geolocation file
longitude DECIMAL(10,6) NULL,
credit_limit DECIMAL(12,2) NULL,         -- Only ML has this
credit_segment VARCHAR(20) NULL,         -- Low / Mid / High
customer_segment VARCHAR(50) NULL,       -- Consumer/Corporate (DataCo only)
source_dataset VARCHAR(10) NOT NULL
);

-- TABLE 4: dim_employee
-- Source   : ML-Dataset.csv only
-- Purpose  : ~50 warehouse employees linked to orders
-- Used by  : Employee performance analysis (unique to ML dataset)
IF OBJECT_ID('dim_employee', 'U') IS NOT NULL DROP TABLE dim_employee;
CREATE TABLE dim_employee (
employee_id INT PRIMARY KEY,
employee_name VARCHAR(200) NOT NULL,
email VARCHAR(200) NULL,
phone VARCHAR(50) NULL,
hire_date DATE NULL,
job_title VARCHAR(200) NULL,
warehouse_id INT NULL REFERENCES dim_warehouse(warehouse_id),
tenure_years DECIMAL(5,1) NULL
);


-- TABLE 5  : dim_seller
-- Source   : olist_sellers + olist_geolocation (aggregated)
-- Purpose  : 3,095 Brazilian marketplace sellers with coordinates
-- Used by  : Seller performance, geographic distribution maps
IF OBJECT_ID('dim_seller', 'U') IS NOT NULL DROP TABLE dim_seller;
CREATE TABLE dim_seller (
seller_id VARCHAR(100) PRIMARY KEY,   -- Olist UUID
zip_code VARCHAR(20) NULL,
seller_city VARCHAR(100) NULL,
seller_state VARCHAR(10) NULL,
seller_lat DECIMAL(10,6) NULL,
seller_lng DECIMAL(10,6) NULL
);

/* -------------------------------------------------
FACT TABLES (transactional / measurement tables)
Create after dimensions — they reference them
----------------------------------------------------*/

-- TABLE 6: fact_orders  ← CENTRAL FACT TABLE
-- Source   : ML-Dataset + DataCo + Olist orders + items (combined)
-- Purpose  : 293,569 order lines — revenue, profit, status, discounts
-- Used by  : Almost every analysis and KPI in the project
IF OBJECT_ID('fact_orders', 'U') IS NOT NULL DROP TABLE fact_orders;
CREATE TABLE fact_orders (
    order_line_id VARCHAR(20) PRIMARY KEY,  -- ML_OL1, DC_OL1, OL_OL1
    order_id VARCHAR(100) NOT NULL,
    product_id VARCHAR(50) NULL REFERENCES dim_product(product_id),
    customer_id VARCHAR(100) NULL REFERENCES dim_customer(customer_id),
    seller_id VARCHAR(100) NULL REFERENCES dim_seller(seller_id),
    warehouse_id INT NULL REFERENCES dim_warehouse(warehouse_id),
    employee_id INT NULL REFERENCES dim_employee(employee_id),
    order_date DATETIME NULL,
    order_year INT NULL,
    order_month INT NULL,
    order_quarter VARCHAR(5) NULL,         -- 'Q1', 'Q2', 'Q3', 'Q4'
    order_status VARCHAR(50) NULL,
    quantity INT NULL,
    unit_price DECIMAL(12,2) NULL,
    discount_amount DECIMAL(12,2)  NULL,         -- NULL for ML and Olist
    discount_rate DECIMAL(8,4) NULL,         -- NULL for ML and Olist
    freight_value DECIMAL(12,2) NULL,         -- NULL for ML and DataCo
    revenue DECIMAL(14,2) NULL,
    profit DECIMAL(14,2) NULL,         -- NULL for Olist
    profit_margin_pct DECIMAL(8,2) NULL,         -- NULL for Olist
    shipping_mode VARCHAR(50) NULL,         -- NULL for ML and Olist
    market VARCHAR(100) NULL,
    late_delivery_risk Decimal(10,2)NULL,         -- 0 or 1, DataCo only
    source_dataset VARCHAR(10) NOT NULL      -- 'ML', 'DataCo', 'Olist'
);


-- TABLE 7: fact_delivery
-- Source   : Olist orders (full timestamps) + DataCo (scheduled vs actual days)
-- Purpose  : ~280,000 delivery records with delay calculations
-- Used by  : Procurement scorecard, VP supply chain KPI dashboard
IF OBJECT_ID('fact_delivery', 'U') IS NOT NULL DROP TABLE fact_delivery;
CREATE TABLE fact_delivery (
    delivery_id INT PRIMARY KEY,
    order_id VARCHAR(100) NOT NULL,
    order_date DATETIME NULL,
    approved_at DATETIME NULL,                        -- Olist only
    delivered_to_carrier DATETIME NULL,               -- Olist only
    delivered_to_customer DATETIME NULL,              -- Olist only
    estimated_delivery DATETIME NULL,                 -- Olist only
    days_to_deliver_actual DECIMAL(10,1) NULL,        -- Olist only
    days_to_deliver_estimated DECIMAL(10,1) NULL,     -- Olist only
    delivery_delay_days DECIMAL(10,1) NULL,           -- Negative = early, Positive = late
    is_late BIT NULL,                                 -- 1 = late, 0 = on time
    days_shipping_real INT NULL,                      -- DataCo only
    days_shipping_scheduled INT NULL,                 -- DataCo only
    delivery_status VARCHAR(100) NULL,                -- DataCo only
    source_dataset VARCHAR(10) NOT NULL
);

-- TABLE 8: fact_reviews
-- Source   : olist_order_reviews only
-- Purpose  : 99,224 customer reviews with sentiment labels
-- Used by  : Customer satisfaction KPIs, VP dashboard
IF OBJECT_ID('fact_reviews', 'U') IS NOT NULL DROP TABLE fact_reviews;
CREATE TABLE fact_reviews (
    review_id VARCHAR(100) PRIMARY KEY,
    order_id VARCHAR(100) NOT NULL,
    review_score INT NULL,                      -- 1 to 5 stars
    review_comment_title VARCHAR(MAX) NULL,
    review_comment VARCHAR(MAX) NULL,
    review_date DATETIME NULL,
    answer_date DATETIME NULL,
    response_time_hrs DECIMAL(10,1) NULL,
    sentiment_label VARCHAR(20) NULL            -- 'Positive','Neutral','Negative'
);


-- TABLE 9: fact_payments
-- Source   : olist_order_payments only
-- Purpose  : 103,886 payment records — type, installments, value
-- Used by  : Finance team — payment mix, cash flow analysis
IF OBJECT_ID('fact_payments', 'U') IS NOT NULL DROP TABLE fact_payments;
CREATE TABLE fact_payments (
    payment_id INT PRIMARY KEY,
    order_id VARCHAR(100) NOT NULL,
    payment_sequential INT NULL,
    payment_type VARCHAR(50) NULL,                -- credit_card, boleto, voucher
    payment_installments INT NULL,
    payment_value DECIMAL(12,2) NULL,
    payment_method_group VARCHAR(20) NULL         -- 'Card', 'Cash', 'Voucher'
);
-- FK 1: fact_orders.product_id → dim_product.product_id
ALTER TABLE fact_orders
ADD CONSTRAINT fk_orders_product
FOREIGN KEY (product_id) REFERENCES dim_product(product_id);

-- FK 2: fact_orders.customer_id → dim_customer.customer_id
ALTER TABLE fact_orders
ADD CONSTRAINT fk_orders_customer
FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id);
 
-- FK 3: dim_employee.warehouse_id → dim_warehouse.warehouse_id
ALTER TABLE dim_employee
ADD CONSTRAINT fk_emp_warehouse
FOREIGN KEY (warehouse_id) REFERENCES dim_warehouse(warehouse_id);
        
 
PRINT 'All 9 tables created successfully.';
GO

 -- BULK INSERT

BULK INSERT dim_warehouse
FROM 'C:\Users\Admin\Desktop\RetailPulse\clean\dim_warehouse.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2);

BULK INSERT dim_product
FROM 'C:\Users\Admin\Desktop\RetailPulse\clean\dim_product.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2);

BULK INSERT dim_customer
FROM 'C:\Users\Admin\Desktop\RetailPulse\clean\dim_customer.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2);

BULK INSERT dim_employee
FROM 'C:\Users\Admin\Desktop\RetailPulse\clean\dim_employee.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2);
SELECT * FROM fact_orders

BULK INSERT dim_seller
FROM 'C:\Users\Admin\Desktop\RetailPulse\clean\dim_seller.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2);

BULK INSERT fact_orders
FROM 'C:\Users\Admin\Desktop\RetailPulse\clean\fact_orders.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2);

BULK INSERT fact_delivery
FROM 'C:\Users\Admin\Desktop\RetailPulse\clean\fact_delivery.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2);

BULK INSERT fact_reviews
FROM 'C:\Users\Admin\Desktop\RetailPulse\clean\fact_reviews.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2);

BULK INSERT fact_payments
FROM 'C:\Users\Admin\Desktop\RetailPulse\clean\fact_payments.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2);

/*-------------------------------
SECTION 3 — VIEWS FOR TABLEAU
---------------------------------*/

-- VIEW 1: vw_executive_kpi
-- For  : VP of Supply Chain — top-level numbers
-- Shows: Total revenue, profit, orders, late rate by source
IF OBJECT_ID('vw_executive_kpi', 'V') IS NOT NULL DROP VIEW vw_executive_kpi;
GO
CREATE VIEW vw_executive_kpi AS
SELECT o.source_dataset,o.order_year,
       o.order_quarter,o.market,
       COUNT(o.order_line_id) AS total_orders,
       SUM(o.revenue) AS total_revenue,
       SUM(o.profit) AS total_profit,
       ROUND(AVG(o.profit_margin_pct),2) AS avg_margin_profit,
       SUM(o.quantity) AS total_unit_sold,
       ROUND(AVG(CAST(o.late_delivery_risk AS float)) * 100,1) AS late_delivery_rate_pct
FROM fact_orders o
GROUP BY o.source_dataset,o.order_year,
       o.order_quarter,o.market;

-- VIEW 2: vw_product_performance
-- For  : Warehouse Manager — SKU-level health
-- Shows: Revenue, margin, order count per product per category

IF OBJECT_ID('vw_product_performance', 'V') IS NOT NULL DROP VIEW vw_product_performance;
GO
CREATE VIEW vw_product_performance AS
SELECT p.product_id, p.product_name,
       p.category, p.standard_cost,
       p.list_price, p.markup_pct,
       p.source_dataset,
       COUNT(o.order_line_id) AS order_count,
       SUM(o.revenue) AS total_revenue,
       SUM(o.profit) AS total_profit,
       ROUND(AVG(o.profit_margin_pct), 2) AS avg_margin_pct,
       SUM(o.quantity) AS total_units_ordered
FROM dim_product p
LEFT JOIN fact_orders o
on p.product_id = o.product_id
GROUP BY p.product_id, p.product_name,
       p.category, p.standard_cost,
       p.list_price, p.markup_pct,
       p.source_dataset;

-- VIEW 3: vw_delivery_performance
-- For  : Procurement Team — supplier/delivery scorecard
-- Shows: Late rate, avg delay, delivery status breakdown
IF OBJECT_ID('vw_delivery_performance', 'V') IS NOT NULL DROP VIEW vw_delivery_performance;
GO
CREATE VIEW vw_delivery_performance AS
SELECT d.source_dataset,d.delivery_status,
       o.shipping_mode,o.market,
       o.order_year,o.order_quarter,
       COUNT(d.delivery_id) AS total_shipments,
       SUM(CAST(d.is_late AS INT)) AS late_shipments,
       ROUND(SUM(CAST(d.is_late AS FLOAT))
       / NULLIF(COUNT(d.delivery_id), 0) * 100 ,1) AS late_rate_pct,
       ROUND(AVG(CAST(d.delivery_delay_days AS FLOAT)),1) AS avg_delay_days,
       ROUND(AVG(CAST(d.days_to_deliver_estimated AS FLOAT)),1) AS avg_estimated_days,
       ROUND(AVG(CAST(d.days_shipping_real AS FLOAT)),1) AS avg_ship_days_real,
       ROUND(AVG(CAST(d.days_shipping_scheduled as FLOAT)),1) as avg_ship_days_sched
FROM fact_delivery d
LEFT JOIN fact_orders o
on o.order_id = d.order_id
GROUP BY d.source_dataset,d.delivery_status,
       o.shipping_mode,o.market,
       o.order_year,o.order_quarter;

-- VIEW 4: vw_customer_satisfaction
-- For   : VP Dashboard — review and sentiment summary
-- Shows : Score distribution, sentiment, response time by period
IF OBJECT_ID('vw_customer_satisfaction', 'V') IS NOT NULL DROP VIEW vw_customer_satisfaction;
GO
CREATE VIEW vw_customer_satisfaction AS
SELECT r.sentiment_label,r.review_score,
       year(r.review_date) AS review_year,
       MONTH(r.review_date) AS review_month,
       COUNT(r.review_date) AS total_reviews,
       ROUND(AVG(CAST(r.review_score AS FLOAT)),2) AS avtg_reveiew_score,
       ROUND(AVG(r.response_time_hrs),1) AS avg_response_hr,
       SUM(CASE WHEN r.review_score >= 4 THEN 1 ELSE 0 END) AS positive_reviews,
       SUM(CASE WHEN r.review_score = 3  THEN 1 ELSE 0 END) AS neutral_reviews,
       SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) AS negative_reviews
FROM fact_reviews r
GROUP BY r.sentiment_label,r.review_score,
         YEAR(r.review_date),
         MONTH(r.review_date);

-- VIEW 5: vw_payment_analysis
-- For  : Finance Team — payment mix and cash flow
-- Shows: Payment type breakdown, installment analysis
IF OBJECT_ID('vw_payment_analysis', 'V') IS NOT NULL DROP VIEW vw_payment_analysis;
GO
CREATE VIEW vw_payment_analysis AS
SELECT p.payment_type,p.payment_installments,
       COUNT(p.payment_id) AS total_transactions,
       SUM(p.payment_value) AS total_payment_val,
       ROUND(AVG(p.payment_value),2) AS avg_payment_val,
       ROUND(AVG(p.payment_installments),1) AS avg_installments
FROM fact_payments p
GROUP BY p.payment_type,p.payment_installments;

-- VIEW 6: vw_warehouse_performance
-- For  : Warehouse Manager — compare all 9 warehouses
-- Shows: Revenue, orders, region per warehouse
IF OBJECT_ID('vw_warehouse_performance', 'V') IS NOT NULL DROP VIEW vw_warehouse_performance;
GO
CREATE VIEW vw_warehouse_performance AS
SELECT w.warehouse_id,w.warehouse_name,
       w.city,w.region,w.country,
       COUNT(o.order_line_id) AS total_orders,
       SUM(o.revenue) AS total_revenue,
       SUM(o.profit) AS total_profit,
       ROUND(AVG(o.profit_margin_pct),2) AS avg_margin_pct, 
       COUNT(DISTINCT o.product_id) AS unique_products,
       COUNT(DISTINCT o.customer_id) AS unique_customers
FROM dim_warehouse w
LEFT JOIN fact_orders o
on w.warehouse_id = o.warehouse_id
GROUP BY w.warehouse_id,w.warehouse_name,
       w.city,w.region,w.country;

/*---------------------------------------------------------------------
   SECTION 4 — BASIC KPI QUERIES
   Run each query individually in SSMS.
   These answer the most direct business questions.
--------------------------------------------------------------------- */

-- Q1: Overall Revenue & Profit Summary 
-- Answers: VP needs top-line numbers first
-- Result : One row per source showing total revenue and profit

SELECT source_dataset,
       COUNT(order_line_id) As total_orders,
       ROUND(SUM(revenue),0) AS total_revenue,
       ROUND(SUM(profit),0) AS total_profit,
       ROUND(AVG(profit_margin_pct), 2) AS avg_margin_pct,
       ROUND(AVG(unit_price), 2) AS avg_order_value
FROM fact_orders
GROUP BY source_dataset
ORDER BY total_revenue DESC;

-- Q2: Revenue by Year and Quarter (Trend Analysis)
-- Answers: Is the business growing? When is the peak season?
-- Finding: DataCo shows sharp revenue decline in late 2017-2018

SELECT source_dataset,order_year,order_quarter,
       ROUND(SUM(revenue),0) AS quaterly_revenue,
       COUNT(order_line_id) AS order_count
FROM fact_orders
GROUP BY source_dataset,order_year,order_quarter
ORDER BY source_dataset,order_year,order_quarter;

-- Q3: Late Delivery Rate by Dataset
-- Answers: How bad is the delivery problem across our operations?
-- Finding: DataCo 54.8% vs Olist 7.3% — massive operational gap

SELECT source_dataset,
       COUNT(delivery_id) AS total_shipments,
       SUM(CAST(is_late AS INT)) AS late_shipments,
       ROUND(SUM(CAST(is_late AS FLOAT)) /
       NULLIF(COUNT(delivery_id),0) * 100,1) AS late_rate_pct,
       ROUND(AVG(CAST(delivery_delay_days AS FLOAT)),1) AS avg_delay_days,
       ROUND(AVG(CAST(days_to_deliver_actual AS FLOAT)),1) AS avg_actual_days
FROM fact_delivery
GROUP BY source_dataset
ORDER BY late_rate_pct DESC; 

-- Q4: Revenue by Product Category
-- Answers: Which categories drive the most value?
-- Stakeholder: Warehouse Manager — where to focus inventory efforts

SELECT p.category,p.source_dataset,
       COUNT(o.order_line_id) AS order_count,
       ROUND(SUM(o.revenue),0) AS total_revenue,
       ROUND(SUM(o.profit),0) AS total_profit,
       ROUND(AVG(o.profit_margin_pct),2) AS avg_margin_pct,
       SUM(o.quantity) AS total_units
FROM fact_orders o
INNER JOIN dim_product p
ON  o.product_id = p.product_id
GROUP BY p.category,p.source_dataset
ORDER BY total_revenue DESC;

-- Q5: Order Status Breakdown
-- Answers: How many orders are stuck, canceled, or delivered?
-- Finding: High pending rate = fulfillment bottleneck
SELECT source_dataset,order_status,
       COUNT(Order_line_id) AS Order_Count,
       ROUND(COUNT(order_line_id) * 100.0/
       SUM(COUNT(order_line_id)) OVER (PARTITION BY source_dataset),1) AS pct_of_dataset    
FROM fact_orders
WHERE order_status IS NOT NULL
GROUP BY source_dataset,order_status
ORDER BY source_dataset,Order_Count DESC;

-- Q6: Customer Review Score Distribution
-- Answers: How satisfied are Olist customers?
-- Finding: 11,282 one-star reviews — hidden risk
SELECT review_score, sentiment_label,
       COUNT(review_id) AS review_count,
       ROUND(COUNT(review_id) * 100.0 /
       SUM(COUNT(review_id)) OVER(),1) AS pct_of_total,
       ROUND(AVG(response_time_hrs),1) AS avg_response_hrs
FROM fact_reviews
GROUP BY review_score, sentiment_label
ORDER BY review_score;

/*----------------------------------------------------------------
   SECTION 5 — INTERMEDIATE ANALYSIS
   Multi-table joins, grouping, and conditional aggregation.
   ----------------------------------------------------------------*/

-- Q7: Shipping Mode vs Late Delivery Rate (DataCo)
-- Answers: Does shipping mode affect late delivery probability?
-- Stakeholder: Procurement — is upgrading shipping worth the cost?

SELECT shipping_mode,
       COUNT(order_line_id) AS total_orders,
       ROUND(SUM(revenue),0) AS total_revenue,
       SUM(late_delivery_risk) AS late_orders,
       ROUND(AVG(CAST(late_delivery_risk AS FLOAT)) * 100,1) AS late_rate_pct,
       ROUND(AVG(profit_margin_pct),2) AS profit_margin_pct,
       ROUND(AVG(unit_price),2) AS avg_order_value
FROM fact_orders
WHERE source_dataset = 'DataCo'
      AND shipping_mode IS NOT NULL
GROUP BY shipping_mode
ORDER BY late_rate_pct DESC;

-- Q8: Revenue by Market (Global View — DataCo)
-- Answers: Which global market generates the most value?
-- Stakeholder: VP Supply Chain — where to invest next

SELECT market,
       COUNT(order_line_id) AS total_orders,
       ROUND(SUM(revenue), 0) AS total_revenue,
       ROUND(AVG(profit_margin_pct), 2) AS avg_margin_pct,
       SUM(late_delivery_risk) AS late_orders,
       ROUND(AVG(CAST(late_delivery_risk AS FLOAT)) * 100, 1) AS late_rate_pct
FROM fact_orders
WHERE source_dataset = 'DataCo'
      AND market IS NOT NULL
GROUP BY market
ORDER BY total_revenue DESC;

-- Q9: Hardware Profitability by Category (ML-Dataset)
-- Answers: Which hardware categories have the best margins?
-- Finding: RAM has highest margin (3.52%) but lowest revenue
SELECT p.category,
       COUNT(o.order_line_id) AS order_count,
       ROUND(SUM(o.revenue),0) AS total_revenue,
       ROUND(SUM(o.profit),0) AS total_profit,
       ROUND(AVG(o.profit_margin_pct),2) AS avg_margin_pct,
       ROUND(MIN(o.unit_price),2) AS min_price,
       ROUND(MAX(o.unit_price),2) AS max_price,
       ROUND(AVG(o.unit_price),2) AS avg_price
FROM fact_orders o
INNER JOIN dim_product p
ON o.product_id = p.product_id
WHERE o.source_dataset = 'ML'
GROUP BY p.category
ORDER BY avg_margin_pct DESC;

-- Q10: Warehouse Performance Comparison
-- Answers: Which of the 9 warehouses is the strongest?
-- Stakeholder: Warehouse Operations Manager
SELECT w.warehouse_name, w.city, w.region, w.country,
       COUNT(o.order_line_id) AS total_orders,
       ROUND(SUM(o.revenue),0) AS total_revenue,
       ROUND(SUM(o.profit),0) AS total_profit,
       ROUND(AVG(o.profit_margin_pct),2) AS avg_margin_pct,
       COUNT(DISTINCT o.product_id) AS unique_skus,
-- Cancellation rate for this warehouse
        ROUND(SUM(CASE WHEN o.order_status = 'Canceled' THEN 1.0 ELSE 0 END)/
        NULLIF(COUNT(o.order_line_id),0) * 100,1) AS cancellation_rate_pct
FROM dim_warehouse w
LEFT JOIN fact_orders o
ON w.warehouse_id = o.warehouse_id
GROUP BY w.warehouse_name, w.city, w.region, w.country
ORDER BY total_revenue DESC;

-- Q11: Employee Order Performance (ML-Dataset)
-- Answers: Which employees handle the highest-value orders?
-- This is unique to ML-Dataset — no other source has employee dat
SELECT e.employee_name, e.job_title, w.warehouse_name,
       w.region, e.tenure_years,
       COUNT(o.order_line_id) AS total_orders_handled,
       ROUND(SUM(o.revenue),0) AS total_revenue_handled,
       ROUND(AVG(o.revenue),2) AS avg_order_value,
       ROUND(SUM(o.profit),0) AS total_profit_handled,
-- Cancellation rate per employee
       SUM(CASE WHEN o.order_status = 'Canceled' THEN 1 ELSE 0 END) AS canceled_orders,
       ROUND(SUM(CASE WHEN o.order_status = 'Canceled' THEN 1.0 ELSE 0 END)/
       NULLIF(COUNT(o.order_line_id),0) * 100, 1) AS cancel_rate
FROM dim_employee e
INNER JOIN dim_warehouse w
ON e.warehouse_id = w.warehouse_id
LEFT JOIN fact_orders o
ON e.employee_id = o.employee_id
GROUP BY e.employee_name, e.job_title, w.warehouse_name,
         w.region, e.tenure_years
ORDER BY total_revenue_handled DESC;

-- Q12: Payment Method Analysis (Olist)
-- Answers: How do Brazilian customers prefer to pay?
-- Stakeholder: Finance Team — cash flow and collection risk
SELECT payment_type,
       COUNT(payment_id) AS transaction_count,
       ROUND(COUNT(payment_id) * 100.0/
       SUM(COUNT(payment_id)) OVER(), 1) AS pct_of_transaction,
       ROUND(SUM(payment_value), 0) AS total_value,
       ROUND(AVG(payment_value), 2) AS avg_payment_value,
       ROUND(AVG(CAST(payment_installments AS FLOAT)),1) AS avg_installments,
       Max(payment_installments) AS max_installments
FROM fact_payments
GROUP BY payment_type
ORDER BY transaction_count DESC;

-- Q13: Orders that never got fulfilled (no product assigned)
SELECT order_status,
       COUNT(*) AS order_count
FROM fact_orders
WHERE source_dataset = 'Olist'
      AND product_id IS NULL
GROUP BY order_status
ORDER BY order_count DESC;

/* ----------------------------------------------------------------
   SECTION 6 — ADVANCED SQL
   Window functions, CTEs, running totals, rankings.
   ---------------------------------------------------------------- */

-- Q14: ABC Classification — Revenue Concentration
-- Business use: Identified A-class products (top 70% revenue)
--               so inventory teams can prioritise them for stockout prevention
-- SQL skills  : CTE + window function (SUM OVER + cumulative %)
WITH category_revenue AS (
    -- Step 1: Total revenue per category
    SELECT p.category,p.source_dataset,    
           ROUND(SUM(o.revenue),0) AS total_revenue
    FROM dim_product p
    INNER JOIN fact_orders o
    ON o.product_id = p.product_id
    GROUP BY p.category,p.source_dataset
),
cumulative AS(
    -- Step 2: Added running total and cumulative % using window function
    SELECT category, source_dataset, total_revenue,
    RANK() OVER(PARTITION BY source_dataset ORDER BY total_revenue DESC) AS revenue_rank,
    ROUND(SUM(total_revenue) OVER(PARTITION BY source_dataset ORDER BY total_revenue DESC
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)/
    SUM(total_revenue) OVER(PARTITION BY source_dataset) * 100, 1) AS cumulative_pct
    FROM category_revenue
)
-- Step 3: Apply ABC classification rule
SELECT category, source_dataset, total_revenue, revenue_rank, cumulative_pct,
       CASE 
            WHEN cumulative_pct <= 70 THEN 'A — High Value (protect from stockout)'
            WHEN cumulative_pct <= 90 THEN 'B — Medium Value (monitor regularly)'
            ELSE 'C — Low Value (review for rationalisation)'
      END AS abc_class      
FROM cumulative
ORDER BY source_dataset, revenue_rank;

-- Q15: Month-over-Month Revenue Growth
-- Business use: Is revenue growing? When did the DataCo drop happen?
-- SQL skills : CTE + LAG window function for previous period comparison
WITH monthly_revenue AS(
    SELECT source_dataset, order_year, order_month,
    ROUND(SUM(revenue),0) AS monthly_revenue
    FROM fact_orders
    WHERE order_year IS NOT NULL AND order_month IS NOT NULL
    GROUP BY source_dataset, order_year, order_month
)
SELECT source_dataset, order_year, order_month,monthly_revenue,
       LAG(monthly_revenue) OVER(PARTITION BY source_dataset
       ORDER BY order_year, order_month) AS prev_month_revenue,

       -- Growth rate: (this month - last month) / last month * 100

       ROUND((monthly_revenue - LAG(monthly_revenue) OVER(PARTITION BY source_dataset
       ORDER BY order_year, order_month)) / NULLIF(LAG(monthly_revenue) OVER(PARTITION BY
       source_dataset ORDER BY order_year, order_month),0) * 100 ,1) AS mom_growth_pct
From monthly_revenue
ORDER BY source_dataset, order_year, order_month;

-- Q16: Delivery Delay Ranking by Market
-- Business use: Which markets have the worst delivery experience?
-- SQL skills  : RANK()
SELECT o.market, o.source_dataset,
       COUNT(d.delivery_id) AS total_shipments,
       SUM(CAST(d.is_late AS INT)) AS late_count,
       ROUND(AVG(CAST(d.is_late AS FLOAT)) * 100, 1) AS late_rate_pct,
       ROUND(AVG(d.delivery_delay_days),1) AS avg_delay_days,
       -- Rank markets from worst to best delivery performance
       RANK() OVER(ORDER BY AVG(CAST(d.is_late AS FLOAT)) DESC) AS late_rate_rank
FROM fact_delivery d
INNER JOIN fact_orders o
ON o.order_id = d.order_id
GROUP BY o.market, o.source_dataset
ORDER BY late_rate_rank;

-- Q17: Running Total Revenue — DataCo
-- Business use: Cumulative revenue to track annual targets
-- SQL skills  : SUM OVER with ORDER BY (running total)
SELECT order_year,order_month,
       ROUND(SUM(revenue),0) AS monthly_revenue,
       ROUND(SUM(SUM(revenue)) OVER(PARTITION BY order_year ORDER BY order_month 
       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),0) AS ytd_revenue,
       ROUND(SUM(SUM(revenue)) OVER(ORDER BY order_year, order_month 
       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),0) AS all_time_running_total
FROM fact_orders
WHERE source_dataset = 'Dataco'
      AND order_year IS NOT NULL
GROUP BY order_year,order_month
ORDER BY order_year,order_month; 

-- Q18: Top 10 Customers by Revenue (DataCo)
-- Business use: Who are our most valuable customers?
-- SQL skills  : JOIN + TOP + RANK window function
SELECT c.customer_name, c.city, c.state, c.customer_segment,
       COUNT(o.order_line_id) AS total_orders,
       ROUND(SUM(o.revenue),0) AS total_revenue,
       ROUND(AVG(o.revenue),2)  AS avg_order_value,
       ROUND(SUM(o.profit),0) AS total_profit,
       RANK() OVER(ORDER BY SUM(o.revenue) DESC) AS revenue_rank
FROM dim_customer c
INNER JOIN fact_orders o
ON c.customer_id = o.customer_id
WHERE o.source_dataset = 'DataCo'
      AND c.customer_name IS NOT NULL
GROUP BY c.customer_name, c.city, c.state, c.customer_segment
ORDER BY total_revenue DESC;

-- Q19: Review Score vs Delivery Performance (Correlation)
-- Business use: Do late deliveries cause bad reviews?
-- Insight : This links fact_orders + fact_delivery + fact_reviews
-- SQL skills : 3-table JOIN with conditional aggregation
SELECT d.is_late,
       CASE
           WHEN d.is_late = 1 THEN 'Late Delivery'
           ELSE 'On-Time Delivery'
       END AS delivery_label,
       COUNT(r.review_id) AS review_count,
       ROUND(AVG(CAST(r.review_score AS FLOAT)), 2) AS avg_review_score,
       SUM(CASE WHEN r.review_score = 5 THEN 1 ELSE 0 END) AS five_star_review,
       SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) AS one_start_review,
       ROUND(SUM(CASE WHEN r.review_score <= 2 THEN 1.0 ELSE 0 END)/
       NULLIF(COUNT(r.review_id), 0) * 100, 1) AS negative_review_pct
FROM fact_delivery d
INNER JOIN fact_orders o
ON o.order_id = d.order_id
INNER JOIN fact_reviews r
ON o.order_id = r.order_id
WHERE d.source_dataset = 'Olist'
      AND d.is_late IS NOT NULL
GROUP BY d.is_late
ORDER BY d.is_late DESC;

-- Q20: Seller Performance Scorecard (Olist)
-- Business use: Which sellers drive the most revenue and satisfaction?
-- Stakeholder : Procurement team — seller relationship management
-- SQL skills  : Multi-table JOIN across 3 tables

SELECT TOP 20 s.seller_id, s.seller_city, s.seller_state,
       COUNT(DISTINCT o.order_id) AS total_orders,
       ROUND(SUM(o.revenue), 0) AS total_revenue,
       ROUND(AVG(r.review_score) ,2) AS avg_review_score,
       COUNT(r.review_id) AS review_count,
       ROUND(AVG(o.freight_value) ,2) AS avg_frieght_cost,
       SUM(CASE WHEN r.sentiment_label = 'Positive' THEN 1 ELSE 0 END) AS positive_reviews,
       SUM(CASE WHEN r.sentiment_label = 'Negative' THEN 1 ELSE 0 END) AS negative_reviews,
       RANK() OVER(ORDER BY SUM(o.revenue) DESC) AS revenue_rank
FROM dim_seller s
INNER JOIN fact_orders o
ON s.seller_id = o.seller_id
LEFT JOIN fact_reviews r
ON o.order_id = r.order_id
GROUP BY s.seller_id, s.seller_city, s.seller_state
HAVING COUNT (DISTINCT o.order_id) >= 10  -- only sellers with meaningful volume
ORDER BY total_revenue DESC;

/*-----------------------------------------------------------------
   SECTION 7 — STAKEHOLDER-SPECIFIC REPORTS
   These queries are written exactly for each stakeholder
   mentioned in the business problem statement.
  -----------------------------------------------------------------*/

-- STAKEHOLDER 1: VP of Supply Chain
-- "I want executive-level KPI numbers — one screen, top metrics"

-- Total Revenue
SELECT 'Total Revenue' AS KPI,CONCAT('$', FORMAT(SUM(revenue),'N0')) AS VALUE
FROM fact_orders
UNION ALL

-- Total Profit
SELECT 'Total Profit', CONCAT('$', FORMAT(SUM(profit), 'N0')) 
FROM fact_orders
WHERE profit IS NOT NULL
UNION ALL

-- Total Orders
SELECT 'Total Orders', FORMAT(COUNT(order_line_id),'N0')
FROM fact_orders
UNION ALL

-- Dataco late delivery rate
SELECT 'Dataco late delivery rate', CONCAT(FORMAT(AVG(CAST(late_delivery_risk AS FLOAT)) * 100 ,'N1'),'%')
FROM fact_orders
WHERE source_dataset = 'Dataco'
UNION ALL

--  OLIST review score
SELECT 'Olist Avg Review Score', FORMAT(AVG(CAST (review_score AS FLOAT)) * 100, 'N2')
FROM fact_reviews
UNION ALL

-- Olist Late Delivery Rate
SELECT 'Olist Late Delivery Rate', CONCAT(FORMAT(AVG(CAST(is_late AS FLOAT)) * 100 ,'N1'),'%')
FROM fact_delivery
WHERE source_dataset = 'Olist'

-- STAKEHOLDER 2: Warehouse Operations Manager
-- "Show me SKU-level performance per warehouse"

SELECT w.warehouse_name,w.region,p.category,p.product_name,
       COUNT(o.order_line_id) AS order_count,
       SUM(o.quantity) AS total_units,
       ROUND(SUM(o.revenue),0) AS total_revenue,
       ROUND(AVG(o.profit_margin_pct),2) AS avg_margin,
       -- Orders canceled for the SKU in this warehouse
       SUM(CASE WHEN o.order_status = 'Canceled' THEN 1 ELSE 0 END) AS canceled_orders,
       ROUND(SUM(CASE WHEN o.order_status = 'Canceled' THEN 1.0 ELSE 0 END) /
       NULLIF(COUNT(o.order_line_id),0) * 100, 1) AS cancel_rate_pct
FROM dim_warehouse w
INNER JOIN fact_orders o
ON o.warehouse_id = w.warehouse_id
INNER JOIN dim_product p
ON o.product_id = p.product_id
WHERE o.source_dataset = 'ML'
GROUP BY w.warehouse_name, w.region,
         p.category, p.product_name
ORDER BY w.warehouse_name, total_revenue DESC;

-- STAKEHOLDER 3: Procurement Team
-- "Give me a supplier performance scorecard"
-- Using DataCo's shipping mode and delivery data as proxy for supplier
SELECT o.shipping_mode AS supplier_channel,
       o.market AS region,
       COUNT(o.order_line_id) AS total_orders,
       SUM(o.late_delivery_risk) AS late_orders,
       ROUND(AVG(CAST(o.late_delivery_risk AS FLOAT)) * 100, 1) AS late_rate_pct,
       ROUND(AVG(d.days_shipping_real), 1) AS avg_ship_days_actual,
       ROUND(AVG(d.days_shipping_scheduled), 1) AS  avg_ship_days_promised,
       ROUND(AVG(CAST(d.delivery_delay_days AS FLOAT)), 1) AS avg_delay_days,
       ROUND(SUM(o.revenue), 0) AS total_order_value,
       -- Score: 100 minus late rate (higher = better supplier)
       ROUND(100 - AVG(CAST(o.late_delivery_risk AS FLOAT)) * 100, 1) AS performance_score
FROM fact_orders o
LEFT JOIN fact_delivery d
ON o.order_id = d.order_id
WHERE o.source_dataset = 'DataCo'
      AND o.shipping_mode IS NOT NULL
GROUP BY o.shipping_mode, o.market
ORDER BY performance_score DESC;

-- STAKEHOLDER 4: Finance Team
-- "What is the financial cost of late deliveries and bad reviews?"

WITH late_cost AS(
     --Estimate: late order loses ~15% of its revenue (returns, discounts, churn)
     SELECT source_dataset,
             COUNT(order_line_id) AS total_orders,
             SUM(CASE WHEN late_delivery_risk = 1 THEN revenue ELSE 0 END)  AS late_order_revenue,
             ROUND(SUM(CASE WHEN late_delivery_risk = 1 THEN revenue ELSE 0 END) * 0.15, 0) AS estimated_late_cost
     FROM fact_orders
     WHERE source_dataset = 'DataCo'
     GROUP BY source_dataset
),
negative_review_cost AS (
    -- Estimate: each negative review represents 3 lost future orders at avg $176
    SELECT COUNT(CASE WHEN sentiment_label = 'Negative' THEN 1 END) AS negative_reviews,
           COUNT(CASE WHEN sentiment_label = 'Negative' THEN 1 END) * 3 * 176 AS estimated_lost_future_revenue
    FROM fact_reviews
)
SELECT lc.total_orders, lc.late_order_revenue, lc.estimated_late_cost AS estimated_loss_from_late_orders,
       nr.negative_reviews, nr.estimated_lost_future_revenue AS estimated_loss_from_bad_reviews,
       lc.estimated_late_cost + nr.estimated_lost_future_revenue AS total_estimated_financial_risk
FROM late_cost lc, negative_review_cost nr;

/* ------------------------------------------------------------------
   SECTION 8 — DATA QUALITY CHECKS
   Run these after loading data to confirm everything is clean.
   Document results as your "data validation report."
   ------------------------------------------------------------------*/
-- Check 1: Row counts match ETL output
SELECT 'dim_warehouse'  AS table_name, COUNT(*) AS row_count FROM dim_warehouse 
UNION ALL
SELECT 'dim_product', COUNT(*) FROM dim_product
UNION ALL
SELECT 'dim_customer', COUNT(*) FROM dim_customer
UNION ALL
SELECT 'dim_employee', COUNT(*) FROM dim_employee
UNION ALL
SELECT 'dim_seller', COUNT(*) FROM dim_seller
UNION ALL
SELECT 'fact_orders', COUNT(*) FROM fact_orders
UNION ALL
SELECT 'fact_delivery', COUNT(*) FROM fact_delivery
UNION ALL
SELECT 'fact_reviews', COUNT(*) FROM fact_reviews
UNION ALL
SELECT 'fact_payments', COUNT(*) FROM fact_payments;

-- Expected: dim_warehouse=9, dim_product=33344, dim_customer=120493,
--           dim_employee=400, dim_seller=3095, fact_orders=294344,
--           fact_delivery=279960, fact_reviews=98410, fact_payments=103886

-- Check 2: Null check on critical columns
SELECT 'fact_orders' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN revenue IS NULL THEN 1 ELSE 0 END) AS null_revenue,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS null_order_date,
    SUM(CASE WHEN source_dataset IS NULL THEN 1 ELSE 0 END) AS null_source,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id
FROM fact_orders;
               
-- Check 3: Orphan records (FK integrity)
-- Are there orders referencing products that don't exist?
SELECT 'Orders with no matching product' AS check_name,
        COUNT(*) AS orphan_count
FROM fact_orders o
LEFT JOIN dim_product p 
ON o.product_id = p.product_id
WHERE p.product_id IS NULL
      AND o.product_id IS NOT NULL;

-- Check 4: Duplicate order_line_id
SELECT order_line_id, COUNT(*) AS duplicate_count
FROM fact_orders
GROUP BY order_line_id
HAVING COUNT(*) > 1;
-- Expected: zero rows returned (no duplicates)

-- Check 5: Revenue sanity check
-- Flag any orders where revenue is negative or suspiciously high
SELECT order_line_id, source_dataset, unit_price, quantity, revenue, 'Anomaly' AS flag
FROM fact_orders
WHERE revenue < 0
      OR revenue > 700000
ORDER BY revenue DESC;

-- Check 6: Date range validation
SELECT source_dataset, MIN(order_date) AS earliest_order,
       MAX(order_date) AS latest_order, DATEDIFF(DAY, MIN(order_date),
       MAX(order_date)) AS date_span_days
FROM fact_orders
WHERE order_date IS NOT NULL
GROUP BY source_dataset;
-- Expected: ML 2013-2017, DataCo 2015-2018, Olist 2016-2018
PRINT '========================================';
PRINT ' RetailPulse SQL Script Complete';
PRINT ' Database  : RetailPulseDB';
PRINT ' Tables    : 9 (5 dim + 4 fact)';
PRINT ' Views     : 6 (for Tableau)';
PRINT ' Queries   : 19 analysis queries';
PRINT ' Checks    : 6 data quality checks';
PRINT '========================================';







