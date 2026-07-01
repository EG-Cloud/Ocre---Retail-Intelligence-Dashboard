--------------------
---------- 1. Data Modeling
--------------------

-- Splitting final_clean into dimension and fact tables
-- for star schema analysis and Power BI consumption

----------
---------- 1.1 dim_products
----------

CREATE TABLE dim_products AS (
	SELECT 
		stock_code, 
		MODE() WITHIN GROUP (ORDER BY description) AS most_freq_description, 
		MODE() WITHIN GROUP (ORDER BY stock_code_type) AS most_freq_sctype
	FROM final_clean
	GROUP BY stock_code
);

----------
---------- 1.2 dim_customers
----------

-- Country: most frequent country used as the customer's home country
-- in case they ordered from multiple locations
-- Recency: number of days since last purchase relative to the last date in the dataset (2011-12-09)

CREATE TABLE dim_customers AS (
	WITH help_table AS (
		SELECT
			customer_id,
			MODE() WITHIN GROUP (ORDER BY country) AS country,
			MIN(invoice_date) AS first_purchase,
			MAX(invoice_date) AS last_purchase,
			COUNT(DISTINCT invoice_number) AS frequency,
			SUM(quantity * price) AS monetary
		FROM final_clean
		GROUP BY customer_id
	)
	SELECT
		customer_id,
		country,
		first_purchase,
		last_purchase,
		EXTRACT(DAY FROM '2011-12-09 12:50:00'::timestamp - last_purchase)::integer AS recency,
		frequency,
		monetary
	FROM help_table
);

----------
---------- 1.3 fact_transactions
----------

CREATE TABLE fact_transactions AS (
	SELECT
		invoice_number,
		invoice_date,
		customer_id,
		stock_code,
		quantity,
		price,
		quantity * price AS revenue,
		order_status = 'cancelled' AS is_return
	FROM final_clean
);

----------
---------- 1.4 Validation
----------

-- Checking for orphan keys in fact_transactions
-- The reverse check (dim → fact) is unnecessary since all tables derive from final_clean

SELECT ft.customer_id, dc.customer_id
FROM fact_transactions ft
LEFT JOIN dim_customers dc ON ft.customer_id = dc.customer_id
WHERE dc.customer_id IS NULL;

SELECT ft.stock_code, dp.stock_code
FROM fact_transactions ft
LEFT JOIN dim_products dp ON ft.stock_code = dp.stock_code
WHERE dp.stock_code IS NULL;