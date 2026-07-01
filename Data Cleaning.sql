--------------------
---------- Introduction Ocre - Online Retail II UCI
--------------------

CREATE TABLE raw_main(
    Invoice VARCHAR(20),
    StockCode VARCHAR(20),
    Description VARCHAR(150),
    Quantity INTEGER,
    InvoiceDate TIMESTAMP,
    Price NUMERIC(10,2),
    "Customer ID" VARCHAR(20),
    Country VARCHAR(40)
);

COPY raw_main
FROM 'C:\Users\Desktop\Projet Ocre\Online Retail II UCI'
DELIMITER ','
CSV HEADER;

--------------------
---------- 1. Initial Exploration
--------------------

-- Dataset dictionary:
-- Invoice:      6-digit transaction number. Prefix 'C' indicates a cancellation.
-- StockCode:    5-digit product code, unique per product.
-- Description:  Product name.
-- Quantity:     Units per transaction.
-- InvoiceDate:  Transaction timestamp.
-- Price:        Unit price in GBP.
-- Customer ID:  5-digit customer identifier. NULL for anonymous checkouts.
-- Country:      Customer's country of residence.

-- Row count
SELECT COUNT(*) AS nb_rows
FROM raw_main;

-- Column count
SELECT COUNT(*) AS nb_columns
FROM information_schema.columns
WHERE table_name = 'raw_main';

-- Overview
SELECT *
FROM raw_main
LIMIT 1000;

-- Column types
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'raw_main';

-- Descriptive statistics
SELECT
    MIN(price)    AS min_price,
    MAX(price)    AS max_price,
    AVG(price)    AS avg_price,
    MIN(quantity) AS min_quantity,
    MAX(quantity) AS max_quantity,
    AVG(quantity) AS avg_quantity
FROM raw_main;

--------------------
---------- 2. Data Cleaning
--------------------

-- Create a working copy to preserve raw data
CREATE TABLE clean_main AS (SELECT * FROM raw_main);

-- Standardize column names
ALTER TABLE clean_main RENAME COLUMN invoice     TO invoice_number;
ALTER TABLE clean_main RENAME COLUMN stockcode   TO stock_code;
ALTER TABLE clean_main RENAME COLUMN invoicedate TO invoice_date;
ALTER TABLE clean_main RENAME COLUMN "Customer ID" TO customer_id;

----------
---------- 2.1 Null Values
----------

-- Identify nulls and their proportion per column
SELECT 
    COUNT(*) AS total, 
    COUNT(*) FILTER(WHERE invoice_number IS NULL) AS null_invoice_number,
    COUNT(*) FILTER(WHERE stock_code IS NULL)     AS null_stock_code,

    COUNT(*) FILTER(WHERE description IS NULL)    AS null_description,
    ROUND(100.0 * COUNT(*) FILTER(WHERE description IS NULL) / COUNT(*), 2) AS null_description_pct,

    COUNT(*) FILTER(WHERE quantity IS NULL)       AS null_quantity,
    COUNT(*) FILTER(WHERE invoice_date IS NULL)   AS null_invoice_date,
    COUNT(*) FILTER(WHERE price IS NULL)          AS null_price,

    COUNT(*) FILTER(WHERE customer_id IS NULL)    AS null_customer_id,
    ROUND(100.0 * COUNT(*) FILTER(WHERE customer_id IS NULL) / COUNT(*), 2) AS null_customer_id_pct,

    COUNT(*) FILTER(WHERE country IS NULL)        AS null_country
FROM clean_main;

-- Results: 0.41% missing descriptions | 22.77% missing customer IDs

-- Replace NULL descriptions with a placeholder
UPDATE clean_main
SET description = 'No description'
WHERE description IS NULL;

-- Treat NULL customer IDs as anonymous guest checkouts
UPDATE clean_main
SET customer_id = 'Guest'
WHERE customer_id IS NULL;

-- Confirm nulls resolved
SELECT 
    ROUND(100.0 * COUNT(*) FILTER(WHERE description IS NULL) / COUNT(*), 2) AS null_description_pct,
    ROUND(100.0 * COUNT(*) FILTER(WHERE customer_id IS NULL) / COUNT(*), 2) AS null_customer_id_pct
FROM clean_main;

----------
---------- 2.2 Invoice Number
----------

-- Identify non-standard invoice numbers (not 6 digits or C + 6 digits)
SELECT invoice_number
FROM clean_main
WHERE invoice_number !~ '^C?[0-9]{6}$';

-- Inspect invoices starting with 'A' (bad debt adjustments)
SELECT *
FROM clean_main
WHERE invoice_number LIKE 'A%';

-- Flag cancelled vs valid orders based on invoice prefix
ALTER TABLE clean_main
ADD COLUMN order_status VARCHAR(20);

UPDATE clean_main
SET order_status = 
    CASE 
        WHEN invoice_number LIKE 'C%' THEN 'cancelled'
        ELSE 'valid' 
    END;

-- Note: 6 invoices starting with 'A' represent bad debt adjustments
-- totalling approximately -£147,614. Retained for financial accuracy.

----------
---------- 2.3 Stock Code
----------

-- Normalize stock codes to uppercase and remove whitespace
UPDATE clean_main
SET stock_code = TRIM(UPPER(stock_code));

-- Inspect non-standard stock codes
SELECT *
FROM clean_main
WHERE stock_code !~ '^[0-9]{5}[A-Z]{0,3}$'
ORDER BY stock_code;

-- Frequency of each non-standard stock code
SELECT 
    stock_code,
    COUNT(*) AS nb_occurrences
FROM (
    SELECT *
    FROM clean_main
    WHERE stock_code !~ '^[0-9]{5}[A-Z]{0,3}$'
) sub
GROUP BY stock_code
ORDER BY nb_occurrences DESC;

-- Classify each stock code by business type
ALTER TABLE clean_main
ADD COLUMN stock_code_type VARCHAR(20);

UPDATE clean_main
SET stock_code_type = 
    CASE
        -- Standard product format: 5 digits + up to 3 uppercase letters
        WHEN stock_code ~ '^[0-9]{5}[A-Z]{0,3}$' THEN 'valid_product'

        -- Post-invoicing corrections — kept for net revenue accuracy
        WHEN stock_code IN ('ADJUST', 'ADJUST2', 'B') THEN 'valid_adjustment'

        -- External fees — kept for P&L, excluded from product metrics
        WHEN stock_code IN ('AMAZON FEE', 'BANK CHARGES') THEN 'valid_expense'

        -- Customer-billed shipping — kept in financial totals,
        -- excluded from product mix and basket analysis
        WHEN stock_code IN ('C2', 'C3', 'DOT', 'POST') THEN 'valid_postage'

        -- Transaction-level discounts — kept for net revenue accuracy
        WHEN stock_code = 'D' THEN 'valid_discount'

        -- Test transactions — no business value, excluded from all analysis
        WHEN stock_code = 'TEST' THEN 'test_invalid'

        -- Codes flagged for review — excluded until confirmed
        WHEN stock_code IN ('CRUK', 'S', 'M', 'PADS', 'SP1002') THEN 'to_confirm_invalid'
        WHEN stock_code LIKE 'GIFT%' THEN 'to_confirm_invalid'
        WHEN stock_code LIKE 'DCG%'  THEN 'to_confirm_invalid'

        ELSE 'to_confirm_invalid'
    END;

----------
---------- 2.4 Description
----------

SELECT COUNT(*) AS no_description_before
FROM clean_main
WHERE description = 'No description';
-- 4223 rows without a description

-- Replace missing descriptions with the most frequently used
-- description for the same stock code
WITH best_description AS (
    SELECT 
        stock_code,
        MODE() WITHIN GROUP (ORDER BY description) AS best_description
    FROM clean_main
    WHERE description != 'No description'
    GROUP BY stock_code
)
UPDATE clean_main t1
SET description = bd.best_description
FROM best_description bd
WHERE t1.stock_code = bd.stock_code
    AND t1.description = 'No description';

SELECT COUNT(*) AS no_description_after
FROM clean_main
WHERE description = 'No description';
-- 361 descriptions could not be filled (no reference found for their stock code)

----------
---------- 2.5 Quantity
----------

-- Check for nulls, decimals, and zero values
SELECT quantity, COUNT(*)
FROM clean_main
WHERE quantity != FLOOR(quantity)
   OR quantity IS NULL
   OR quantity = 0
GROUP BY quantity
ORDER BY quantity;

----------
---------- 2.6 Invoice Date
----------

-- Verify date range
SELECT
    MIN(invoice_date) AS earliest,
    MAX(invoice_date) AS latest
FROM clean_main;
-- Range: 2009-12-01 to 2011-12-09

-- Check for future or impossible dates
SELECT COUNT(*)
FROM clean_main
WHERE invoice_date > NOW();
-- Result: 0 future dates

----------
---------- 2.7 Price
----------

-- Descriptive statistics including median
SELECT 
    MIN(price)    AS min_price,
    MAX(price)    AS max_price,
    AVG(price)    AS avg_price,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) AS median_price
FROM clean_main;

-- Inspect negative prices (bad debt adjustments — expected)
SELECT *
FROM clean_main
WHERE price < 0;

-- Count zero prices by validity
SELECT COUNT(*) AS nb_zero_valid
FROM clean_main
WHERE price = 0
    AND stock_code_type LIKE 'valid%';
-- 6135 valid rows with zero price

SELECT COUNT(*) AS nb_zero_invalid
FROM clean_main
WHERE price = 0
    AND stock_code_type NOT LIKE 'valid%';
-- 85 invalid rows with zero price

-- Identify valid stock codes with no non-zero price reference
-- (cannot be auto-filled — require manual review)
SELECT
    stock_code,
    COUNT(*) AS nb_total,
    COUNT(*) FILTER (WHERE price = 0)  AS nb_zeros,
    COUNT(*) FILTER (WHERE price != 0) AS nb_non_zeros
FROM clean_main
WHERE stock_code_type LIKE 'valid%'
GROUP BY stock_code
HAVING COUNT(*) FILTER (WHERE price != 0) = 0
    AND COUNT(*) FILTER (WHERE price = 0)  > 0;
-- 350 stock codes cannot be auto-filled

SELECT COUNT(*) AS zero_price_before
FROM clean_main
WHERE price = 0
    AND stock_code_type LIKE 'valid%';
-- 6135

-- Replace zero prices with the most frequent price for the same stock code
WITH best_price AS (
    SELECT
        stock_code,
        MODE() WITHIN GROUP (ORDER BY price) AS most_frequent_price
    FROM clean_main
    WHERE price != 0
        AND stock_code_type LIKE 'valid%'
    GROUP BY stock_code
)
UPDATE clean_main t1
SET price = bp.most_frequent_price
FROM best_price AS bp
WHERE t1.stock_code = bp.stock_code
    AND t1.price = 0                            -- only replace zeros
    AND t1.stock_code_type LIKE 'valid%';

SELECT COUNT(*) AS zero_price_after
FROM clean_main
WHERE price = 0
    AND stock_code_type LIKE 'valid%';
-- 368 zeros remaining (stock codes with no price reference)

-- Flag remaining zero prices for review
ALTER TABLE clean_main
ADD COLUMN price_validity VARCHAR(20);

UPDATE clean_main
SET price_validity = 
    CASE
        WHEN price != 0 THEN 'valid'
        ELSE 'invalid'
    END;

----------
---------- 2.8 Customer ID
----------

-- Inspect customer ID format (expected: 5-digit number)
SELECT customer_id
FROM clean_main
WHERE customer_id != 'Guest'
    AND customer_id ~ '^[0-9]{5}\.[0-9]?'
GROUP BY customer_id;
-- All non-guest IDs have a trailing '.0' that must be removed

-- Strip trailing decimal suffix from customer IDs
UPDATE clean_main
SET customer_id = LEFT(customer_id, 5)
WHERE customer_id != 'Guest';

----------
---------- 2.9 Country
----------

-- Review all distinct country values
SELECT DISTINCT country
FROM clean_main;

-- Standardize country name variants
UPDATE clean_main SET country = 'Ireland'      WHERE country = 'EIRE';
UPDATE clean_main SET country = 'South Africa' WHERE country = 'RSA';

-- Normalize casing and trim whitespace
UPDATE clean_main
SET country = TRIM(INITCAP(country));

----------
---------- 2.10 Duplicates
----------

-- Identify duplicate rows (same invoice, stock code, and customer)
SELECT 
    invoice_number,
    stock_code,
    customer_id,
    COUNT(*) AS nb_occurrences
FROM clean_main
GROUP BY invoice_number, stock_code, customer_id
HAVING COUNT(*) > 1
ORDER BY nb_occurrences DESC;

-- Flag duplicates (keep first occurrence per group)
ALTER TABLE clean_main
ADD COLUMN is_duplicate BOOLEAN DEFAULT FALSE;

WITH ranked AS (
    SELECT 
        ctid,
        ROW_NUMBER() OVER (
            PARTITION BY invoice_number, stock_code, customer_id
            ORDER BY ctid
        ) AS rn
    FROM clean_main
)
UPDATE clean_main t1
SET is_duplicate = TRUE
FROM ranked r
WHERE t1.ctid = r.ctid
    AND r.rn > 1;

-- Verify flagging results
SELECT 
    is_duplicate,
    COUNT(*) AS nb_rows
FROM clean_main
GROUP BY is_duplicate;
-- 45.950 rows flagged as duplicates

--------------------
---------- 3. Final Clean Table
--------------------

-- Create analysis-ready table excluding all flagged/invalid rows
CREATE TABLE final_clean AS
SELECT *
FROM clean_main
WHERE is_duplicate = FALSE
    AND stock_code_type LIKE 'valid%'
    AND stock_code_type != 'test_invalid'
    AND price_validity = 'valid'
    AND order_status = 'valid';

-- Final row count
SELECT COUNT(*) AS final_row_count FROM final_clean;

-- Distribution check
SELECT stock_code_type, COUNT(*) FROM final_clean GROUP BY 1 ORDER BY 2 DESC;
SELECT order_status,    COUNT(*) FROM final_clean GROUP BY 1;
SELECT price_validity,  COUNT(*) FROM final_clean GROUP BY 1;
SELECT is_duplicate,    COUNT(*) FROM final_clean GROUP BY 1;