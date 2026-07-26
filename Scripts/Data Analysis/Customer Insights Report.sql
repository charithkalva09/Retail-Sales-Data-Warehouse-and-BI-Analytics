/*
===============================================================================
Customer Report
===============================================================================
Purpose:
    - This report consolidates key customer metrics and behaviors

Highlights:
    1. Gathers essential fields such as names, ages, and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and age groups.
    3. Aggregates customer-level metrics:
	   - total orders
	   - total sales
	   - total quantity purchased
	   - total products
	   - lifespan (in months)
    4. Calculates valuable KPIs:
	    - recency (months since last order)
		- average order value
		- average monthly spend
===============================================================================
*/

DROP VIEW IF EXISTS customer_report;

CREATE OR REPLACE VIEW customer_report AS
-- Base Query: Retrieves core columns from tables
WITH base_query AS
         (
            SELECT
                s.order_number,
                s.product_key,
                s.order_date,
                s.sales_amount,
                s.quantity,
                c.customer_key,
                c.customer_number,
                CONCAT(c.first_name, ' ', c.last_name) customer_name,
                EXTRACT(YEAR FROM AGE(c.birth_date)) customer_age,
                c.gender
            FROM fact_sales s
            LEFT JOIN dim_customers c ON s.customer_key = c.customer_key
            WHERE s.order_date IS NOT NULL
        ),

-- Customer Aggregations: Summarizes key metrics at the customer level
    customer_segmentation AS
        (
            SELECT
                customer_key,
                customer_number,
                customer_name,
                customer_age,
                gender,
                COUNT(DISTINCT order_number) total_orders,
                SUM(sales_amount) total_sales,
                SUM(quantity) total_quantity,
                COUNT(DISTINCT product_key) total_products,
                MAX(order_date) last_order,
                EXTRACT(YEAR FROM AGE(MAX(order_date), MIN(order_date))) * 12 +
                EXTRACT(MONTHS FROM AGE(MAX(order_date), MIN(order_date))) order_lifespan
            FROM base_query
            GROUP BY 1,2,3,4,5
        )
    SELECT
        customer_key,
        customer_number,
        customer_name,
        customer_age,
        CASE
            WHEN customer_age < 30 THEN 'Under 30'
            WHEN customer_age BETWEEN 30 AND 39 THEN '30-39'
            WHEN customer_age BETWEEN 40 AND 49 THEN '40-49'
            WHEN customer_age BETWEEN 50 AND 60 THEN '50-60'
            ELSE 'Above 60'
        END age_group,
        CASE
            WHEN order_lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
            WHEN order_lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
            ELSE 'New'
        END customer_group,
        gender,
        last_order,
        EXTRACT(YEARS FROM AGE(last_order)) * 12 order_recency,
        total_orders,
        total_sales,
        total_quantity,
        total_products,
        order_lifespan,
        CASE
            WHEN total_quantity >= 1 THEN DIV(total_sales,total_orders)
            ELSE 0
        END avg_order_value,
        CASE
            WHEN order_lifespan = 0 THEN total_sales
            ELSE DIV(total_sales,order_lifespan)
        END avg_monthly_spending
    FROM customer_segmentation;