-- Total Revenue, Customers and Quantity by Year?
SELECT
    EXTRACT('YEAR' FROM order_date) order_year,
    SUM(sales_amount) total_revenue,
    COUNT(DISTINCT customer_key) total_customers,
    SUM(quantity) total_quantity
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY 1;


-- Total Revenue, Customers and Quantity by Month and Year?
-- Approach 1
SELECT
    EXTRACT('Month' FROM order_date) month_number,
    TO_CHAR(order_date,'Mon') month_number,
    EXTRACT('YEAR' FROM order_date) order_year,
    SUM(sales_amount) total_revenue,
    COUNT(DISTINCT customer_key) total_customers,
    SUM(quantity) total_quantity
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY 1,2,3
ORDER BY 3,1;

-- Approach 2
SELECT
    DATE_TRUNC('MONTH',order_date)::DATE order_date,
    SUM(sales_amount) total_revenue,
    COUNT(DISTINCT customer_key) total_customers,
    SUM(quantity) total_quantity
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY 1
ORDER BY 1;


-- Total Sales, Running Total Sales AND Total Average Price, Moving Total Average Price per Month
SELECT
    order_month,
    total_sales,
    SUM(total_sales) OVER (PARTITION BY order_month ORDER BY order_month) running_total_sales,
    AVG(ROUND(avg_price,0)) OVER (PARTITION BY order_month ORDER BY order_month) moving_avg_price
FROM
    (
        SELECT
            date_trunc('MONTH',order_date)::DATE order_month,
            SUM(sales_amount) total_sales,
            AVG(price) avg_price
        FROM fact_sales
        WHERE order_date IS NOT NULL
        GROUP BY 1
    )t;


-- Total Sales, Running Total Sales AND Total Average Price, Moving Total Average Price per Year
SELECT
    order_year,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_year) running_total_sales,
    avg_price,
    AVG(avg_price) OVER (ORDER BY order_year) moving_avg_price
FROM
    (
        SELECT
            EXTRACT('YEAR' FROM order_date) order_year,
            SUM(sales_amount) total_sales,
            ROUND(AVG(price),0) avg_price
        FROM fact_sales
        WHERE order_date IS NOT NULL
        GROUP BY 1
    )t;


/*
    Analyze the yearly performance of products by comparing each products sales to both its average sales performance
    and the previous year's sales.
*/
WITH yearly_performance AS
    (
    SELECT
        EXTRACT('YEAR' FROM s.order_date) order_year,
        p.product_name,
        SUM(s.sales_amount) current_sales
    FROM fact_sales s
    LEFT JOIN gold.dim_products p on s.product_key = p.product_key
    WHERE s.order_date IS NOT NULL
    GROUP BY 2,1
    )

SELECT
    *,
    AVG(current_sales) OVER (PARTITION BY product_name) avg_sales,
    current_sales -  AVG(current_sales) OVER (PARTITION BY product_name) avg_diff,
    CASE
        WHEN current_sales -  AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Average'
        WHEN current_sales -  AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Average'
        ELSE 'Average'
    END AS avg_status,
    LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) py_sales, -- YOY Analysis
    current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) sales_diff,
    CASE
        WHEN  current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
        WHEN  current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
        ELSE 'No Change'
    END AS sales_status
FROM yearly_performance;


-- Which categories contribute the most to overall sales
WITH category_sales AS
     (
        SELECT p.category,
             SUM(s.sales_amount) total_sales
        FROM fact_sales s
        LEFT JOIN dim_products p ON s.product_key = p.product_key
        GROUP BY 1
        ORDER BY 2 DESC
    )

SELECT
    *,
    SUM(total_sales) OVER() overall_sales,
    ROUND(total_sales / SUM(total_sales) OVER()*100,2) percentage_of_total
FROM category_sales;


-- Product cost Segmentation
WITH cost_segemnt AS
     (
     SELECT product_key,
             product_name,
             cost,
             CASE
                 WHEN cost < 100 THEN 'Below 100'
                 WHEN cost BETWEEN 100 AND 500 THEN '100-500'
                 WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
                 WHEN cost BETWEEN 1000 AND 2000 THEN '1000-2000'
                 ELSE 'Above 2000'
                 END cost_range
      FROM dim_products
     )

SELECT
    cost_range,
    COUNT(product_key)
FROM cost_segemnt
GROUP BY 1
ORDER BY 2 DESC;


-- Customers Segmentation based on their spending index
WITH customer_spending AS
        (
        SELECT
            c.customer_key,
            SUM(s.sales_amount) total_spending,
            MIN(order_date) first_order,
            MAX(order_date) last_order,
            EXTRACT(YEAR FROM AGE(MAX(order_date), MIN(order_date))) * 12 +
            EXTRACT(MONTHS FROM AGE(MAX(order_date), MIN(order_date))) order_history
        FROM fact_sales s
        LEFT JOIN dim_customers c on s.customer_key = c.customer_key
        GROUP BY 1
        )

SELECT
    customer_type,
    COUNT(customer_key) total_customers
FROM (
        SELECT
            customer_key,
            order_history,
            total_spending,
            CASE
                WHEN order_history >= 12 AND total_spending > 5000 THEN 'VIP'
                WHEN order_history >= 12 AND total_spending <= 5000 THEN 'Regular'
                ELSE 'New'
            END customer_type
        FROM customer_spending
        GROUP BY 1, 2, 3
    ) t
GROUP BY 1
ORDER BY 2 DESC;