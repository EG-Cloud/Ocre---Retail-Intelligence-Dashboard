--------------------
---------- 2. RFM Segmentation
--------------------

-- Overview of the customer base before scoring
SELECT * 
FROM dim_customers;

----------
---------- 2.1 Distribution Analysis
----------

-- Percentile distribution of R, F, M values
-- Used to understand the spread of data before assigning scores
SELECT
    PERCENTILE_CONT(0.20) WITHIN GROUP (ORDER BY recency)   AS recency_p20,
    PERCENTILE_CONT(0.40) WITHIN GROUP (ORDER BY recency)   AS recency_p40,
    PERCENTILE_CONT(0.60) WITHIN GROUP (ORDER BY recency)   AS recency_p60,
    PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY recency)   AS recency_p80,

    PERCENTILE_CONT(0.20) WITHIN GROUP (ORDER BY frequency) AS frequency_p20,
    PERCENTILE_CONT(0.40) WITHIN GROUP (ORDER BY frequency) AS frequency_p40,
    PERCENTILE_CONT(0.60) WITHIN GROUP (ORDER BY frequency) AS frequency_p60,
    PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY frequency) AS frequency_p80,

    PERCENTILE_CONT(0.20) WITHIN GROUP (ORDER BY monetary)  AS monetary_p20,
    PERCENTILE_CONT(0.40) WITHIN GROUP (ORDER BY monetary)  AS monetary_p40,
    PERCENTILE_CONT(0.60) WITHIN GROUP (ORDER BY monetary)  AS monetary_p60,
    PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY monetary)  AS monetary_p80
FROM dim_customers;

----------
---------- 2.2 Scoring and Segmentation
----------

-- Score each customer from 1 to 5 on R, F, M using NTILE quintiles
-- Recency  : fewer days since last purchase = better = higher score (DESC)
-- Frequency: more orders = better = higher score (ASC)
-- Monetary : higher spend = better = higher score (ASC)
-- Segment rules:
--   VIP        → high scores across all three dimensions
--   Loyal      → strong recency and frequency
--   At Risk    → low recency but historically frequent
--   Lost       → low recency and low frequency
--   Occasional → everything else

CREATE TABLE customer_segments_rfm AS (
    WITH rfm_scores AS (
        SELECT
            customer_id,
            recency,
            frequency,
            monetary,
            NTILE(5) OVER (ORDER BY recency  DESC) AS recency_score,
            NTILE(5) OVER (ORDER BY frequency ASC)  AS frequency_score,
            NTILE(5) OVER (ORDER BY monetary  ASC)  AS monetary_score
        FROM dim_customers
    )
    SELECT
        customer_id,
        recency,
        frequency,
        monetary,
        recency_score,
        frequency_score,
        monetary_score,
        CONCAT(recency_score, frequency_score, monetary_score) AS rfm_score,
        CASE
            WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'VIP'
            WHEN recency_score >= 3 AND frequency_score >= 3                          THEN 'Loyal'
            WHEN recency_score <= 2 AND frequency_score >= 3                          THEN 'At Risk'
            WHEN recency_score <= 2 AND frequency_score <= 2                          THEN 'Lost'
            ELSE 'Occasional'
        END AS segment
    FROM rfm_scores
);

----------
---------- 2.3 Validation
----------

-- Overview of the scored table
SELECT * 
FROM customer_segments_rfm;

-- Segment distribution : check that all segments are reasonably populated
-- and that averages are consistent with segment definitions
SELECT 
    segment,
    COUNT(*)                    AS nb_customers,
    ROUND(AVG(recency))         AS avg_recency,
    ROUND(AVG(frequency))       AS avg_frequency,
    ROUND(AVG(monetary))        AS avg_monetary,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(segment) FROM customer_segments_rfm),2) AS pct_total
FROM customer_segments_rfm
GROUP BY segment
ORDER BY avg_monetary DESC;