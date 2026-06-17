-- ============================================================================
-- FASE 3: CAPA ANALYTICS - TABLAS ANALÍTICAS Y MÉTRICAS AGREGADAS
-- Base de Datos: Compartamos_Banco (SQL Server)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. ESTRUCTURAS DDL: DIMENSIONES EN LA CAPA ANALYTICS
-- Justificación: Preservamos los catálogos limpios finales listos para consumo.
-- ----------------------------------------------------------------------------

-- DROP previo por idempotencia
IF OBJECT_ID('dbo.dim_cliente_analytics', 'U') IS NOT NULL DROP TABLE dbo.dim_cliente_analytics;
IF OBJECT_ID('dbo.dim_producto_analytics', 'U') IS NOT NULL DROP TABLE dbo.dim_producto_analytics;

-- Crear Dimensión Cliente
CREATE TABLE dbo.dim_cliente_analytics (
    customer_id INT PRIMARY KEY,              -- ID único del cliente (Clave primaria)
    first_name VARCHAR(100),                  -- Nombre en mayúsculas estandarizado
    last_name VARCHAR(100),                   -- Apellido en mayúsculas estandarizado
    email VARCHAR(150),                       -- Correo electrónico limpio
    phone VARCHAR(50),                        -- Teléfono formateado
    age INT,                                  -- Edad corregida (valores lógicos o NULL)
    country VARCHAR(100),                     -- País de residencia
    join_date DATE,                           -- Fecha de registro homologada
    monthly_income DECIMAL(12,2),             -- Ingreso mensual numérico
    fecha_carga DATETIME DEFAULT GETDATE()    -- Auditoría de carga del registro
);

-- Crear Dimensión Producto
CREATE TABLE dbo.dim_producto_analytics (
    product_id INT PRIMARY KEY,               -- ID único del producto (Clave primaria)
    product_name VARCHAR(200),                -- Nombre comercial en mayúsculas
    category VARCHAR(100),                    -- Categoría del producto
    price_usd DECIMAL(10,2),                  -- Precio base en dólares (positivo)
    supplier VARCHAR(150),                    -- Nombre del proveedor
    [status] VARCHAR(50),                     -- Estado actual en el catálogo
    fecha_carga DATETIME DEFAULT GETDATE()    -- Auditoría de carga del registro
);


-- ----------------------------------------------------------------------------
-- 2. ESTRUCTURAS DDL: TABLONES DE DATOS (MÉTRICAS)
-- Justificación: Almacenan KPIs precalculados para optimizar el rendimiento.
-- ----------------------------------------------------------------------------

IF OBJECT_ID('dbo.fact_cliente_analytics', 'U') IS NOT NULL DROP TABLE dbo.fact_cliente_analytics;
IF OBJECT_ID('dbo.fact_producto_analytics', 'U') IS NOT NULL DROP TABLE dbo.fact_producto_analytics;

-- Crear Tablón de Métricas de Cliente
CREATE TABLE dbo.fact_cliente_analytics (
    customer_id INT PRIMARY KEY,              -- ID único del cliente (FK a dim_cliente)
    total_ordenes INT,                        -- Cantidad total de pedidos realizados
    total_unidades_compradas INT,             -- Suma de productos adquiridos
    gasto_total_usd DECIMAL(12,2),            -- Total monetario invertido histórico
    ticket_promedio_usd DECIMAL(10,2),        -- Gasto medio por orden individual
    descuento_promedio_aplicado DECIMAL(5,2), -- Porcentaje medio de descuento recibido
    fecha_ultima_compra DATETIME,             -- Fecha del pedido más reciente
    fecha_carga DATETIME DEFAULT GETDATE()
);

-- Crear Tablón de Métricas de Producto
CREATE TABLE dbo.fact_producto_analytics (
    product_id INT PRIMARY KEY,               -- ID único del producto (FK a dim_producto)
    unidades_vendidas INT,                    -- Cantidad acumulada de unidades ordenadas
    ingresos_totales_usd DECIMAL(12,2),       -- Suma de total_amount_usd por producto
    veces_pedido INT,                         -- Frecuencia de aparición en órdenes
    stock_actual_disponible INT,              -- Inventario remanente en tienda
    descuento_medio_producto DECIMAL(5,2),    -- Descuento promedio asignado
    fecha_carga DATETIME DEFAULT GETDATE()
);


-- ============================================================================
-- 3. SCRIPTS DE INGESTA Y AGREGACIÓN DE DATOS (POBLADO DE CAPA)
-- ============================================================================

-- A. Poblar Dimensiones Directas
INSERT INTO dbo.dim_cliente_analytics (customer_id, first_name, last_name, email, phone, age, country, join_date, monthly_income)
SELECT customer_id, first_name, last_name, email, phone, age, country, join_date, monthly_income FROM dbo.dim_customers;

INSERT INTO dbo.dim_producto_analytics (product_id, product_name, category, price_usd, supplier, [status])
SELECT product_id, product_name, category, price_usd, supplier, [status] FROM dbo.dim_products;


-- B. Poblar Tablón Analítico: fact_cliente_analytics
INSERT INTO dbo.fact_cliente_analytics (customer_id, total_ordenes, total_unidades_compradas, gasto_total_usd, ticket_promedio_usd, descuento_promedio_aplicado, fecha_ultima_compra)
SELECT 
    customer_id,
    COUNT(DISTINCT order_id) AS total_ordenes,
    SUM(quantity) AS total_unidades_compradas,
    SUM(total_amount_usd) AS gasto_total_usd,
    AVG(total_amount_usd) AS ticket_promedio_usd,
    AVG(discount_applied) AS descuento_promedio_aplicado,
    MAX(order_date) AS fecha_ultima_compra
FROM dbo.fact_orders
GROUP BY customer_id;


-- C. Poblar Tablón Analítico: fact_producto_analytics
INSERT INTO dbo.fact_producto_analytics (product_id, unidades_vendidas, ingresos_totales_usd, veces_pedido, stock_actual_disponible, descuento_medio_producto)
SELECT 
    p.product_id,
    ISNULL(SUM(o.quantity), 0) AS unidades_vendidas,
    ISNULL(SUM(o.total_amount_usd), 0) AS ingresos_totales_usd,
    COUNT(o.order_id) AS veces_pedido,
    p.stock_quantity AS stock_actual_disponible,
    ISNULL(AVG(o.discount_applied), 0) AS descuento_medio_producto
FROM dbo.dim_products p
LEFT JOIN dbo.fact_orders o ON p.product_id = o.product_id
GROUP BY p.product_id, p.stock_quantity;