--------------------
---------- 3. Revenue Forecasting
--------------------

-- Four forecast tables, one per model x scope combination:
-- products vs business, Prophet vs ARIMA

-- Note: Prophet tables include a 'y' column (actual historical values),
-- since Prophet reconstructs predictions for the full timeline (past + future).
-- ARIMA tables don't, since ARIMA only forecasts forward and never

----------
---------- 3.1 Prophet
----------

CREATE TABLE forecast_results_products_prophet (
    ds          DATE,
    y           NUMERIC(12,2),  -- actual value (NULL for future dates)
    yhat        NUMERIC(12,2),  -- predicted value
    yhat_lower  NUMERIC(12,2),  -- confidence interval, lower bound
    yhat_upper  NUMERIC(12,2),  -- confidence interval, upper bound
    model       VARCHAR(20),    -- 'Prophet' or 'ARIMA'
    granularity VARCHAR(10),    -- 'daily' or 'weekly'
    run_date    TIMESTAMP DEFAULT NOW()
);

SELECT * FROM forecast_results_products_prophet;

CREATE TABLE forecast_results_business_prophet (
    ds          DATE,
    y           NUMERIC(12,2),
    yhat        NUMERIC(12,2),
    yhat_lower  NUMERIC(12,2),
    yhat_upper  NUMERIC(12,2),
    model       VARCHAR(20),
    granularity VARCHAR(10),
    run_date    TIMESTAMP DEFAULT NOW()
);

SELECT * FROM forecast_results_business_prophet;

----------
---------- 3.2 ARIMA
----------

CREATE TABLE forecast_results_products_arima (
    ds          DATE,
    yhat        NUMERIC(12,2),
    yhat_lower  NUMERIC(12,2),
    yhat_upper  NUMERIC(12,2),
    model       VARCHAR(20),
    granularity VARCHAR(10),
    run_date    TIMESTAMP DEFAULT NOW()
);

SELECT * FROM forecast_results_products_arima;

CREATE TABLE forecast_results_business_arima (
    ds          DATE,
    yhat        NUMERIC(12,2),
    yhat_lower  NUMERIC(12,2),
    yhat_upper  NUMERIC(12,2),
    model       VARCHAR(20),
    granularity VARCHAR(10),
    run_date    TIMESTAMP DEFAULT NOW()
);

SELECT * FROM forecast_results_business_arima;

----------
---------- 3.3 Creating a Power BI-ready table
----------

CREATE TABLE forecast_all AS

SELECT *, 'products' AS scope
FROM forecast_results_products_prophet

UNION ALL

SELECT *, 'business' AS scope
FROM forecast_results_business_prophet

UNION ALL

-- ARIMA hasn't 'y' column, we have to add one just life for scope
SELECT 
    ds,
    NULL AS y,
    yhat,
    yhat_lower,
    yhat_upper,
    model,
    granularity,
    run_date,
    'products' AS scope
FROM forecast_results_products_arima

UNION ALL

SELECT 
    ds,
    NULL AS y,
    yhat,
    yhat_lower,
    yhat_upper,
    model,
    granularity,
    run_date,
    'business' AS scope
FROM forecast_results_business_arima;