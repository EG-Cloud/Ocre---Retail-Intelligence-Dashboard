# Ocre — Retail Intelligence Dashboard

A end-to-end data analytics project applied to a real-world e-commerce dataset.
From raw data cleaning to interactive Power BI dashboards, covering SQL modeling,
Python forecasting and customer segmentation.

---

## Project Overview

Ocre is a fictional UK-based e-commerce retailer selling gift and homeware products
across multiple countries. This project simulates the work of a data analyst building
a full analytics pipeline from scratch — cleaning raw transactional data, modeling it
into a star schema, applying machine learning techniques and delivering business
insights through interactive dashboards.

**Dataset** : Online Retail II — UCI Machine Learning Repository
2 years of transactions (December 2009 – December 2011)
~1M rows | 8 columns | 40+ countries

---

## Stack

- **PostgreSQL** (pgAdmin) — data cleaning, star schema modeling, RFM scoring
- **Python** — forecasting (Prophet, ARIMA) and segmentation (KMeans)
- **Power BI Desktop** — 4 interactive dashboards

**Python libraries** : pandas, sqlalchemy, prophet, pmdarima, scikit-learn

---

## Project Structure

ocre/

│

├── sql/

│   ├── data_cleaning.sql

│   ├── data_modeling.sql

│   ├── rfm_segmentation.sql

│   ├── revenue_forecasting.sql

│   └── segmentation_kmeans.sql

│

├── python/

│   ├── forecast_prophet.ipynb

│   ├── forecast_arima.ipynb

│   └── segmentation_kmeans.ipynb

│

├── powerbi/

│   └── ocre_dashboards.pbix

│

├── data/

│   └── online_retail_II.csv

│

└── README.md

---

## Data Pipeline

Raw CSV (1M rows)

↓

PostgreSQL — Cleaning & Modeling

→ Null handling, standardization, duplicate flagging

→ Star schema : fact_transactions + dim_customers

+ dim_products + dim_date

→ RFM scoring (NTILE quintiles)

↓

Python — Forecasting & Segmentation

→ Prophet : weekly revenue forecast (MAE ≈ 15%)

→ ARIMA   : weekly revenue forecast (MAE ≈ 29%)

→ KMeans  : customer clustering (K=4, Elbow Method)

↓

Power BI — 4 Interactive Dashboards

---

## Key Results

### Business Performance (2010–2011)

| Metric | 2009 | 2010 | 2011 |
|---|---|---|---|
| Total Revenue | £853K | £9.62M | £8.91M |
| Total Orders | 1,853 | 22,492 | 20,257 |
| Total Customers | 1,045 | 4,246 | 4,233 |
| AOV | £460 | £427 | £439 |
| Return Rate | 17.42% | 15.44% | 13.98% |

### Key Insights

**H1 ✅ Confirmed** — Sales peak strongly in Q4 (November–December), 
confirming a clear seasonal holiday effect.

**H2 ✅ Confirmed** — Revenue drops significantly in January after the 
holiday peak.

**H10 ✅ Confirmed** — The United Kingdom dominates revenue by a large 
margin. Despite not having the highest AOV, the UK generates the most 
orders by far.

**H5 ✅ Confirmed** — A small minority of customers (VIP + Key Accounts) 
generates a disproportionate share of total revenue, consistent with 
the Pareto principle.

**H15 ✅ Confirmed** — Revenue grew significantly from 2009 to 2010, 
then stabilized in 2011.

**Unexpected discovery** — KMeans clustering revealed the existence of 
2 Key Account customers (wholesalers) with an average monetary value of 
£766K and average frequency of 2,466 orders — profiles that manual RFM 
scoring alone would not have isolated.

### Customer Segmentation

**RFM Segmentation (SQL)**
5 segments — VIP, Loyal, At Risk, Lost, Occasional
VIP customers generate significantly more revenue than all other segments combined.
Segment distribution is relatively balanced across the customer base.

**KMeans Clustering (Python)**
4 clusters — Key Account (2 customers), Wholesaler (38 customers),
Regular (3,859 customers), To Reactivate (2,000 customers)
34% of customers are flagged as To Reactivate — a significant 
reactivation opportunity for the marketing team.

### Forecasting

**Prophet** — MAE ≈ 15% on weekly product revenue.
Automatically detects yearly seasonality and holiday peaks.
Best suited for this dataset given the limited history (2 years).

**ARIMA** — MAE ≈ 29% on weekly product revenue.
Higher error rate explained by limited training data —
104 weeks barely covers two full seasonal cycles.
Both models predict revenue growth in 2012, with Prophet 
projecting a stronger Q4 uplift.

---

## Hypotheses — Full Results

| # | Hypothesis | Result |
|---|---|---|
| H1 | Sales increase strongly in Nov–Dec | ✅ Confirmed |
| H2 | Sales drop in January after Christmas | ✅ Confirmed |
| H3 | Certain weeks generate more sales | ✅ Confirmed (Q4 pattern) |
| H4 | The series is not stationary | ✅ Confirmed (ARIMA required differencing) |
| H5 | 20% of customers generate ~80% of revenue | ✅ Confirmed |
| H6 | Loyal customers have higher average value | ✅ Confirmed |
| H7 | Customers inactive for 90+ days are likely churned | ⚠️ Partially — flagged as To Reactivate |
| H8 | A minority of products generates most sales | ✅ Confirmed |
| H9 | Cheaper products are bought in higher quantities | ✅ Confirmed |
| H10 | UK dominates revenue | ✅ Confirmed |
| H11 | Negative quantities = returns | ✅ Confirmed |
| H12 | Rows without CustomerID limit customer analysis | ✅ Confirmed (treated as Guest) |
| H13 | Some products are frequently bought together | ❌ Not tested in this project |
| H14 | Some customers have a regular purchase cycle | ⚠️ Partially — visible in frequency scores |
| H15 | Revenue increases from 2009 to 2011 | ✅ Confirmed (2009→2010), stabilized in 2011 |

---

## Known Limitations

- **Saturday excluded** — No valid_product transactions on Saturdays 
in the cleaned dataset. Saturday orders exist in raw data but fall 
outside the product scope.
- **Guest customers** — ~23% of transactions have no customer ID. 
Grouped as Guest and excluded from segmentation.
- **ARIMA training data** — 104 weeks of history limits ARIMA's ability 
to learn seasonal patterns reliably.
- **Data period** — December 2009 to December 2011 only. 
Forecasts should be interpreted with caution.
- **H13 not tested** — Market basket analysis (association rules) 
was not implemented in this version.

---

## Setup

**1 — PostgreSQL**
Create a database and run the SQL scripts in this order:

1. data_cleaning.sql
2. data_modeling.sql
3. rfm_segmentation.sql
4. revenue_forecasting.sql
5. segmentation_kmeans.sql

**2 — Python**
```bash
pip install pandas sqlalchemy prophet pmdarima scikit-learn matplotlib
```
Update the connection string in each notebook:
```python
engine = create_engine(
    "postgresql+psycopg2://username:password@localhost:5432/your_database"
)
```
Run notebooks in this order:

1. forecast_prophet.ipynb
2. forecast_arima.ipynb
3. segmentation_kmeans.ipynb

**3 — Power BI**
Open `ocre_dashboards.pbix` and update the PostgreSQL connection
under Transform Data → Data Source Settings.

---

## About

Built by **ELG** as a portfolio project to develop skills across 
the full data analytics stack.

*Dataset — Online Retail II, UCI Machine Learning Repository*
*Tools — PostgreSQL · Python · Power BI Desktop*
