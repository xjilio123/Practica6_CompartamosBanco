-- ============================================================================
-- FASE 2: CAPA STAGE - LIMPIEZA, MODELADO Y CONTROL DE CALIDAD (BLINDADO)
-- Base de Datos: Compartamos_Banco (SQL Server)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TABLA INTERMEDIA: dim_customers
-- ----------------------------------------------------------------------------
WITH ClientesFiltrados AS (
    SELECT 
        CAST(REPLACE(REPLACE(customer_id, '"', ''), '''', '') AS INT) AS customer_id,
        UPPER(TRIM(first_name)) AS first_name,
        UPPER(TRIM(last_name)) AS last_name,
        UPPER(TRIM(email)) AS email,
        TRIM(phone) AS phone,
        CASE 
            WHEN TRY_CAST(REPLACE(age, '"', '') AS INT) < 0 OR TRY_CAST(REPLACE(age, '"', '') AS INT) > 120 THEN NULL 
            ELSE TRY_CAST(REPLACE(age, '"', '') AS INT) 
        END AS age,
        UPPER(TRIM(country)) AS country,
        TRY_CONVERT(DATE, join_date, 120) AS join_date, 
        TRIM(card_number) AS card_number,
        TRY_CAST(REPLACE(monthly_income, '"', '') AS DECIMAL(12,2)) AS monthly_income,
        ROW_NUMBER() OVER (
            PARTITION BY REPLACE(customer_id, '"', '') 
            ORDER BY (SELECT NULL)
        ) AS indice_duplicado
    FROM dbo.raw_customers
    WHERE customer_id IS NOT NULL 
      AND customer_id <> 'NULL' 
      AND TRIM(customer_id) <> ''
      AND NOT (first_name IS NULL AND last_name IS NULL AND email IS NULL)
)
SELECT 
    customer_id, 
    first_name, 
    last_name, 
    email,
    phone,
    age,
    country,
    join_date,
    card_number,
    monthly_income,
    GETDATE() AS fecha_actualizacion_stage
INTO dbo.dim_customers
FROM ClientesFiltrados
WHERE indice_duplicado = 1;


-- ----------------------------------------------------------------------------
-- 2. TABLA INTERMEDIA: dim_products
-- ----------------------------------------------------------------------------
WITH ProductosFiltrados AS (
    SELECT 
        CAST(REPLACE(REPLACE(product_id, '"', ''), '''', '') AS INT) AS product_id,
        UPPER(TRIM(product_name)) AS product_name,
        UPPER(TRIM(category)) AS category,
        ABS(TRY_CAST(REPLACE(price_usd, '"', '') AS DECIMAL(10,2))) AS price_usd,
        CASE 
            WHEN TRY_CAST(REPLACE(stock_quantity, '"', '') AS INT) < 0 THEN 0 
            ELSE TRY_CAST(REPLACE(stock_quantity, '"', '') AS INT) 
        END AS stock_quantity,
        CASE 
            WHEN TRY_CAST(REPLACE(discount_pct, '"', '') AS DECIMAL(5,2)) > 100.00 THEN 100.00
            WHEN TRY_CAST(REPLACE(discount_pct, '"', '') AS DECIMAL(5,2)) < 0 THEN 0
            ELSE TRY_CAST(REPLACE(discount_pct, '"', '') AS DECIMAL(5,2))
        END AS discount_pct,
        UPPER(TRIM(supplier)) AS supplier,
        UPPER(TRIM([status])) AS [status],
        ROW_NUMBER() OVER (
            PARTITION BY REPLACE(product_id, '"', '') 
            ORDER BY (SELECT NULL)
        ) AS indice_duplicado
    FROM dbo.raw_products
    WHERE product_id IS NOT NULL AND product_id <> 'NULL' AND TRIM(product_id) <> ''
)
SELECT 
    product_id,
    product_name,
    category,
    price_usd,
    stock_quantity,
    discount_pct,
    supplier,
    [status],
    GETDATE() AS fecha_actualizacion_stage
INTO dbo.dim_products
FROM ProductosFiltrados
WHERE indice_duplicado = 1;


-- ----------------------------------------------------------------------------
-- 3. TABLA INTERMEDIA / HECHOS: fact_orders
-- ----------------------------------------------------------------------------
WITH OrdenesFiltradas AS (
    SELECT 
        CAST(REPLACE(REPLACE(order_id, '"', ''), '''', '') AS INT) AS order_id,
        CAST(REPLACE(REPLACE(customer_id, '"', ''), '''', '') AS INT) AS customer_id,
        CAST(REPLACE(REPLACE(product_id, '"', ''), '''', '') AS INT) AS product_id,
        TRY_CONVERT(DATETIME, order_date, 120) AS order_date,
        CASE 
            WHEN TRY_CAST(REPLACE(quantity, '"', '') AS INT) <= 0 THEN 1 
            ELSE TRY_CAST(REPLACE(quantity, '"', '') AS INT) 
        END AS quantity,
        ABS(TRY_CAST(REPLACE(unit_price, '"', '') AS DECIMAL(10,2))) AS unit_price,
        TRY_CAST(REPLACE(discount_applied, '"', '') AS DECIMAL(5,2)) AS discount_applied,
        TRY_CAST(REPLACE(total_amount_usd, '"', '') AS DECIMAL(10,2)) AS total_amount_usd,
        UPPER(TRIM(order_status)) AS order_status,
        UPPER(TRIM(payment_method)) AS payment_method,
        UPPER(TRIM(shipping_country)) AS shipping_country,
        UPPER(TRIM(store_flavor)) AS store_flavor,
        ROW_NUMBER() OVER (
            PARTITION BY REPLACE(order_id, '"', '') 
            ORDER BY (SELECT NULL)
        ) AS indice_duplicado
    FROM dbo.raw_orders
    WHERE order_id IS NOT NULL AND order_id <> 'NULL' AND TRIM(order_id) <> ''
)
SELECT 
    order_id,
    customer_id,
    product_id,
    order_date,
    quantity,
    unit_price,
    discount_applied,
    total_amount_usd,
    order_status,
    payment_method,
    shipping_country,
    store_flavor,
    GETDATE() AS fecha_actualizacion_stage
INTO dbo.fact_orders
FROM OrdenesFiltradas
WHERE indice_duplicado = 1;