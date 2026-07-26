/*
===============================================================================
Product Report
===============================================================================
Purpose:
    - This report consolidates key product metrics and behaviors.

Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    3. Aggregates product-level metrics:
       - total orders
       - total sales
       - total quantity sold
       - total customers (unique)
       - lifespan (in months)
    4. Calculates valuable KPIs:
       - recency (months since last sale)
       - average order revenue (AOR)
       - average monthly revenue
===============================================================================
*/

DROP VIEW IF EXISTS products_report;

CREATE OR REPLACE VIEW products_report AS
-- Base Query: Retrieves core columns from fact_sales and dim_products
WITH base_query AS
    (
        SELECT
            s.order_number,
            s.order_date,
            s.customer_key,
            s.sales_amount,
            s.quantity,
            p.product_key,
            p.product_name,
            p.category,
            p.subcategory,
            p.cost
        FROM fact_sales s
        LEFT JOIN dim_products p ON s.product_key = p.product_key
        WHERE s.order_date IS NOT NULL
    ),

-- Product Aggregations: Summarizes key metrics at the product level
product_aggregations AS
    (
        SELECT
            product_key,
            product_name,
            category,
            subcategory,
            cost,
            EXTRACT(YEAR FROM AGE(MAX(order_date), MIN(order_date))) * 12 +
            EXTRACT(MONTHS FROM AGE(MAX(order_date), MIN(order_date))) order_lifespan,
            MAX(order_date) AS last_sale_date,
            COUNT(DISTINCT order_number) AS total_orders,
            COUNT(DISTINCT customer_key) AS total_customers,
            SUM(sales_amount) AS total_sales,
            SUM(quantity) AS total_quantity,
            ROUND(AVG(sales_amount / NULLIF(quantity, 0)),2) AS avg_selling_price
        FROM base_query
        GROUP BY 1,2,3,4,5
    )

-- Final Query: Combines all product results into one output
SELECT
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	last_sale_date,
	EXTRACT(YEARS FROM AGE(last_sale_date)) * 12 order_recency,
	CASE
		WHEN total_sales > 50000 THEN 'High-Performer'
		WHEN total_sales >= 10000 THEN 'Mid-Range'
		ELSE 'Low-Performer'
	END AS product_segment,
	order_lifespan,
	total_orders,
	total_sales,
	total_quantity,
	total_customers,
	avg_selling_price,
	-- Average Order Revenue (AOR)
	CASE
		WHEN total_orders = 0 THEN 0
		ELSE total_sales / total_orders
	END AS avg_order_revenue,
	-- Average Monthly Revenue
	CASE
		WHEN order_lifespan = 0 THEN total_sales
		ELSE ROUND(total_sales / order_lifespan,2)
	END AS avg_monthly_revenue
FROM product_aggregations;