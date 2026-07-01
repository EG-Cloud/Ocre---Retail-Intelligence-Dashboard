--------------------
---------- 4. Segmentation (KMeans)
--------------------

CREATE TABLE segmentation_rfm_kmeans (
	customer_id VARCHAR(20),
	recency NUMERIC(12,2),
	frequency NUMERIC(12,2),
	monetary NUMERIC(12,2),
	cluster_id VARCHAR(20)
)

SELECT *
FROM segmentation_rfm_kmeans;

----------
---------- 4.1 Creating a Power BI-ready table
----------

CREATE TABLE segmentation_all AS

SELECT 
	s1.customer_id,
	s1.recency,
	s1.frequency,
	s1.monetary,
	s1.rfm_score,
	s1.segment AS pgsql_segment,
	s2.cluster_id AS pyth_segment
FROM customer_segments_rfm s1
INNER JOIN segmentation_rfm_kmeans s2
ON s1.customer_id = s2.customer_id;
