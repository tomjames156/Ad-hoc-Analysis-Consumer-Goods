USE gdb023;



SHOW TABLES; -- Gets all tables in the database
-- dim_product;
-- fact_gross_price;
-- fact_manufacturing_cost;
-- fact_pre_invoice_deductions;
-- fact_sales_monthly;



-- 1) Distinct markets where Atliq Exclusive offers operates in the APAC region
SELECT DISTINCT market
FROM dim_customer
WHERE customer = 'Atliq Exclusive' 
	AND region = 'APAC';



-- 2) Percentage increase of unique products in 2021 vs 2020
WITH unique_prds_2020 AS(
SELECT COUNT(DISTINCT product_code) AS prd_count_2020
FROM fact_sales_monthly
WHERE fiscal_year = 2020
), unique_prds_2021 AS (
SELECT COUNT(DISTINCT product_code) AS prd_count_2021
FROM fact_sales_monthly
WHERE fiscal_year = 2021
) SELECT prd_count_2020, prd_count_2021, CONCAT(ROUND(((prd_count_2021 - prd_count_2020) / prd_count_2020) * 100, 2), '%') AS percentage_change
FROM unique_prds_2020 
JOIN unique_prds_2021; -- cross join, No Query condition



-- 3) Unique product counts for each segment
SELECT segment, COUNT(DISTINCT product_code) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;



-- 4) Increase in unique products in 2020 vs 2021 by segment 
WITH prods_2020 AS (
SELECT segment, 
COUNT(DISTINCT sales.product_code) AS product_count_2020
FROM fact_sales_monthly AS sales
JOIN dim_product AS prd
	ON sales.product_code = prd.product_code
WHERE fiscal_year = 2020
GROUP BY segment
), prods_2021 AS (
SELECT segment, 
COUNT(DISTINCT sales.product_code) AS product_count_2021
FROM fact_sales_monthly AS sales
JOIN dim_product AS prd
	ON sales.product_code = prd.product_code
WHERE fiscal_year = 2021
GROUP BY segment
)
SELECT p20.segment, product_count_2020, product_count_2021, (product_count_2021 - product_count_2020) AS difference
FROM prods_2020 AS p20
JOIN prods_2021 AS p21
	ON p20.segment = p21.segment;



-- 5) products with the highest and lowest manufacturing costs
WITH max_min_cost_prods AS (
SELECT product_code, manufacturing_cost
FROM fact_manufacturing_cost
WHERE manufacturing_cost IN (
	SELECT MAX(manufacturing_cost)
	FROM fact_manufacturing_cost
	UNION 
	SELECT MIN(manufacturing_cost)
	FROM fact_manufacturing_cost
)
)SELECT prds.product_code, product, manufacturing_cost
FROM max_min_cost_prods AS mmp
JOIN dim_product AS prds
	ON mmp.product_code = prds.product_code;



-- 6) Top 5 companies with high average pre invoice discount percentages
SELECT DISTINCT cust.customer_code, customer,
ROUND(AVG(pre_invoice_discount_pct) * 100, 2) AS average_discount_percentage
FROM dim_customer AS cust
JOIN fact_pre_invoice_deductions AS invoices
	ON cust.customer_code = invoices.customer_code
WHERE market = 'India' 
	AND fiscal_year = 2021
GROUP BY cust.customer_code, customer
ORDER BY average_discount_percentage DESC
LIMIT 5;



-- 7) Gross monthly sales for Atliq Exclusive
WITH product_sales AS (
	SELECT `date`, sales.product_code, 
    (sold_quantity * gross_price) AS sales_amount
	FROM fact_gross_price AS price
	JOIN fact_sales_monthly AS sales
		ON price.product_code = sales.product_code
		AND sales.fiscal_year = sales.fiscal_year
	WHERE customer_code IN (
		SELECT customer_code
		FROM dim_customer
        WHERE customer = 'Atliq Exclusive'
	)
)
SELECT MONTHNAME(`date`) AS `Month`, YEAR(`date`) AS `Year`, SUM(sales_amount) AS gross_sales_amount
FROM product_sales
GROUP BY YEAR(`date`), MONTHNAME(`date`)
ORDER BY `Year`, gross_sales_amount DESC;



-- 8) Quarterly sales quantities in 2021
SELECT QUARTER(`date`) AS quarter, SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY QUARTER(`date`)
ORDER BY total_sold_quantity;



-- 9) Gross sales 2021 with percentage contributions by channel
WITH prd_sales_channels AS (
	SELECT DISTINCT `channel`, product_code, SUM(sold_quantity) as qty_sold
	FROM dim_customer AS cust
	JOIN fact_sales_monthly AS sales
		ON cust.customer_code = sales.customer_code
	WHERE fiscal_year = 2021
	GROUP BY `channel`, product_code
), channel_sales_21 AS (
	SELECT `channel`, gross_price * qty_sold AS gross_sales
    FROM fact_gross_price AS price
    JOIN prd_sales_channels AS pschans
		ON price.product_code = pschans.product_code
    WHERE fiscal_year = 2021
), channel_gross_sales AS (
	SELECT `channel`, ROUND(SUM(gross_sales) / 1000000, 2) AS gross_sales_mln
    FROM channel_sales_21
    GROUP BY channel
)
SELECT channel, gross_sales_mln, ROUND((gross_sales_mln / SUM(gross_sales_mln) OVER()) * 100, 2) AS percentage
FROM channel_gross_sales;



-- 10) Top 3 most sold products for each division in 2021
WITH divisions_product_sales AS (
SELECT division, sales.product_code, product, SUM(sold_quantity) AS total_sold_quantity
FROM dim_product AS prods
JOIN fact_sales_monthly AS sales
	ON prods.product_code = sales.product_code
WHERE fiscal_year = 2021
GROUP BY division, sales.product_code, product
), divisions_sales_qty_ranked AS (
SELECT division, product_code, product, total_sold_quantity, RANK() OVER( PARTITION BY division ORDER BY total_sold_quantity DESC)  AS rank_order
FROM divisions_product_sales
)
SELECT *
FROM divisions_sales_qty_ranked
WHERE rank_order <= 3;
