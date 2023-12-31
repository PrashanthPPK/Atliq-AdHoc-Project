
#1 Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region
SELECT customer, market, region FROM dim_customer WHERE customer LIKE '%atliq exclusive%' AND region = 'APAC';

#2 What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields
WITH Distinct_Product AS (
SELECT 
	COUNT(DISTINCT CASE WHEN fs.fiscal_year = 2020 THEN p.product END) as count_product_2020,
	COUNT(DISTINCT CASE WHEN fs.fiscal_year = 2021 THEN p.product END) as count_product_2021
FROM dim_product as p JOIN fact_sales_monthly fs
ON p.product_code = fs.product_code
)
SELECT 
	count_product_2020, 
	count_product_2021, 
	ROUND(((count_product_2021 - count_product_2020)*100/count_product_2020),2) as Percentage_chg
FROM Distinct_Product;

#3 Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.
SELECT segment, COUNT(DISTINCT(product)) as product_count FROM dim_product GROUP BY segment ORDER BY product_count DESC;

#4 Follow-up: Which segment had the most increase in unique products in 2021 vs 2020?
WITH segment_product_count AS 
(
SELECT
	p.segment,
	COUNT(DISTINCT CASE WHEN fs.fiscal_year = 2020 THEN fs.product_code END) as count_product_2020,
    COUNT(DISTINCT CASE WHEN fs.fiscal_year = 2021 THEN fs.product_code END) as count_product_2021
FROM dim_product as p JOIN fact_sales_monthly fs
ON p.product_code = fs.product_code
GROUP BY segment
)
SELECT *, (count_product_2021 - count_product_2020) as Product_difference_2021_To_2020 FROM segment_product_count
ORDER BY Product_difference_2021_To_2020 DESC;

#5 Get the products that have the highest and lowest manufacturing costs.
SELECT 
	p.product, 
    p.product_code, 
    ROUND(fmc.manufacturing_cost,2) as Manufacturing_Cost
FROM dim_product p JOIN fact_manufacturing_cost fmc
ON p.product_code = fmc.product_code
WHERE 
	manufacturing_cost = (SELECT min(manufacturing_cost) FROM fact_manufacturing_cost) OR 
	manufacturing_cost = (SELECT max(manufacturing_cost) FROM fact_manufacturing_cost)
 ORDER BY Manufacturing_Cost DESC;
 
#6 Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market.
SELECT preinv.customer_code, c.customer, ROUND(AVG(preinv.pre_invoice_discount_pct)*100,2) as Average_preinv_pct FROM dim_customer c 
JOIN fact_pre_invoice_deductions preinv
ON c.customer_code = preinv.customer_code
WHERE preinv.fiscal_year = 2021 AND c.market = 'India'
GROUP BY c.customer_code, c.customer
ORDER BY Average_preinv_pct DESC
LIMIT 5;

#7 Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . This analysis helps to get an idea of low and high-performing months and take strategic decisions.
SELECT 
	c.customer as Customer, 
    MONTHNAME(fs.date) as Month_Name, 
    YEAR(fs.date) as Year,
    ROUND((fs.sold_quantity*gp.gross_price),2) AS Gross_Sales_Amount 
FROM fact_sales_monthly fs JOIN fact_gross_price gp
ON fs.product_code = gp.product_code AND fs.fiscal_year = gp.fiscal_year
JOIN dim_customer c ON c.customer_code = fs.customer_code
WHERE c.customer LIKE '%atliq exclusive%';

#8 In which quarter of 2020, got the maximum total_sold_quantity?
WITH CTE1 AS 
(
SELECT
CASE
	WHEN Month(fs.date) IN (7, 8,9) THEN 'Q1'
	WHEN Month(fs.date) IN (10,11,12) THEN 'Q2'
	WHEN Month(fs.date) IN (1,2,3) THEN 'Q3'
	ELSE 'Q4'
END AS Qtr,
SUM(sold_quantity) as Total_Sold_Quantity
FROM fact_sales_monthly fs
GROUP BY Qtr
)
SELECT * FROM CTE1 WHERE Total_Sold_Quantity = (SELECT MAX(Total_Sold_Quantity) FROM CTE1);

#9 Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?
WITH CTE1 AS
(
SELECT 
	c.channel AS Channel_,
    ROUND(SUM((fs.sold_quantity*gp.gross_price))/1000000,2) AS Gross_Sales_Amount_min
FROM fact_sales_monthly fs LEFT JOIN fact_gross_price gp
ON fs.product_code = gp.product_code AND fs.fiscal_year = gp.fiscal_year
JOIN dim_customer c ON c.customer_code = fs.customer_code
WHERE fs.fiscal_year = 2021
GROUP BY c.channel
)
SELECT Channel_, CONCAT('$',Gross_Sales_Amount_min) as Gross_Sales_Min,
CONCAT(ROUND(Gross_Sales_Amount_min/SUM(Gross_Sales_Amount_min)OVER()*100,2), '%') AS Percentage_Contribution
FROM CTE1 GROUP BY Channel_
ORDER BY Percentage_Contribution DESC;


#10 Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021?
WITH TopProducts AS 
(
SELECT p.division, p.product, ROUND(SUM(fs.sold_quantity)/1000000,2) as Total_Sold_Quantity_min
FROM dim_product p JOIN fact_sales_monthly fs ON p.product_code = fs.product_code
WHERE fs.fiscal_year = 2021
GROUP BY p.product, p.division
),
productrank AS
(
SELECT *, DENSE_RANK() OVER (PARTITION by division ORDER BY Total_Sold_Quantity_min) AS Top_Products FROM TopProducts
)
SELECT * FROM productrank WHERE Top_Products<=3;