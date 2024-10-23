-- CREATE SCHEMA dannys_diner;
-- SET search_path = dannys_diner;

-- CREATE TABLE sales (
--   "customer_id" VARCHAR(1),
--   "order_date" DATE,
--   "product_id" INTEGER
-- );

-- INSERT INTO sales
--   ("customer_id", "order_date", "product_id")
-- VALUES
--   ('A', '2021-01-01', '1'),
--   ('A', '2021-01-01', '2'),
--   ('A', '2021-01-07', '2'),
--   ('A', '2021-01-10', '3'),
--   ('A', '2021-01-11', '3'),
--   ('A', '2021-01-11', '3'),
--   ('B', '2021-01-01', '2'),
--   ('B', '2021-01-02', '2'),
--   ('B', '2021-01-04', '1'),
--   ('B', '2021-01-11', '1'),
--   ('B', '2021-01-16', '3'),
--   ('B', '2021-02-01', '3'),
--   ('C', '2021-01-01', '3'),
--   ('C', '2021-01-01', '3'),
--   ('C', '2021-01-07', '3');
 

-- CREATE TABLE menu (
--   "product_id" INTEGER,
--   "product_name" VARCHAR(5),
--   "price" INTEGER
-- );

-- INSERT INTO menu
--   ("product_id", "product_name", "price")
-- VALUES
--   ('1', 'sushi', '10'),
--   ('2', 'curry', '15'),
--   ('3', 'ramen', '12');
  

-- CREATE TABLE members (
--   "customer_id" VARCHAR(1),
--   "join_date" DATE
-- );

-- INSERT INTO members
--   ("customer_id", "join_date")
-- VALUES
--   ('A', '2021-01-07'),
--   ('B', '2021-01-09');

SELECT * FROM members;
SELECT * FROM menu;
SELECT * FROM sales;


/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?

SELECT s.customer_id, SUM(price) AS total_amount_spent 
FROM sales AS s
INNER JOIN
menu AS m
ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id ASC;

-- 2. How many days has each customer visited the restaurant?

SELECT customer_id, count(distinct order_date) AS number_of_days 
FROM sales
GROUP BY customer_id
ORDER BY customer_id ASC;


-- 3. What was the first item from the menu purchased by each customer?

WITH cte AS
(SELECT s.customer_id, m.product_name, 
ROW_NUMBER() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) rownum
FROM sales s
JOIN menu m
ON s.product_id = m.product_id)
select customer_id, product_name 
FROM cte WHERE rownum = 1;



-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT m.product_name, count(product_name) AS order_count 
FROM menu m
JOIN sales s
ON m.product_id = s.product_id
GROUP BY m.product_name
ORDER BY count(product_name) DESC
LIMIT 1;


-- 5. Which item was the most popular for each customer?

WITH item_count AS
(SELECT s.customer_id, m.product_name, COUNT(*) AS order_count, 
DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY COUNT(*) DESC) AS rn
FROM sales s
JOIN
menu m
ON s.product_id = m.product_id
GROUP BY s.customer_id, m.product_name)

SELECT customer_id, product_name 
FROM item_count
WHERE rn = 1 



-- 6. Which item was purchased first by the customer after they became a member?

WITH orders AS
(SELECT s.customer_id, m.product_name, s.order_date, mb.join_date, 
DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY order_date) as rn
FROM sales s
JOIN 
menu m
ON m.product_id = s.product_id
JOIN
members mb
ON s.customer_id = mb.customer_id
WHERE s.order_date > mb.join_date)
SELECT customer_id, product_name 
FROM orders
WHERE rn = 1;

-- 7. Which item was purchased just before the customer became a member?

WITH orders AS
(SELECT s.customer_id, m.product_name, s.order_date, mb.join_date, 
DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY order_date DESC) as rn
FROM sales s
JOIN 
menu m
ON m.product_id = s.product_id
JOIN
members mb
ON s.customer_id = mb.customer_id
WHERE s.order_date < mb.join_date)
SELECT customer_id, product_name 
FROM orders
WHERE rn = 1;

-- 8. What is the total items and amount spent for each member before they became a member?

SELECT s.customer_id, COUNT(m.product_id) AS total_items_ordered, SUM(price) AS total_amount_spent 
FROM sales s
JOIN
menu m
ON s.product_id = m.product_id
JOIN
members mb
ON s.customer_id = mb.customer_id
WHERE s.order_date < mb.join_date
GROUP BY s.customer_id
ORDER BY s.customer_id;


-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH cte AS
(SELECT s.customer_id, m.product_name, m.price,
CASE
	WHEN m.product_name = 'sushi' THEN m.price*10*2
	ELSE m.price*10
	END as points
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
)
SELECT customer_id, SUM(points) AS total_points 
FROM cte
GROUP BY customer_id
ORDER BY customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

WITH cte AS (
    SELECT 
        s.customer_id, 
        m.product_name, 
        m.price, 
        s.order_date, 
        mb.join_date,
        CASE 
            -- Condition for orders placed within 7 days of joining
            WHEN s.order_date BETWEEN mb.join_date AND (mb.join_date + INTERVAL '7 day') THEN m.price * 10 * 2
            -- Condition for the product name 'sushi'
            WHEN m.product_name = 'sushi' THEN m.price * 10 * 2
            -- Default points calculation
            ELSE m.price * 10
        END AS points
    FROM 
        menu AS m
    JOIN 
        sales AS s ON s.product_id = m.product_id
    JOIN 
        members AS mb ON s.customer_id = mb.customer_id
    -- Restricting to orders placed before '2021-02-01'
    WHERE 
        s.order_date < '2021-02-01'
)
-- Summing the points for each customer
SELECT 
    customer_id, 
    SUM(points) AS total_points
FROM 
    cte
GROUP BY 
    customer_id;


-- 11. Determine the name and price of the product ordered by each customer 
-- on all order dates and find out whether the customer was a member on the order date 
-- or not.

SELECT s.customer_id, m.product_name, s.order_date, m.price,
CASE
	WHEN mb.join_date <= s.order_date THEN 'Y'
	ELSE 'N'
	END as member 
FROM menu m
JOIN sales s
ON s.product_id = m.product_id
LEFT JOIN members mb
ON mb.customer_id = s.customer_id;


-- 12. Rank the previous output from Q.11 based on the order_date for each customer. 
-- Display NULL if customer was not a member when dish was ordered.

WITH cte AS
(SELECT s.customer_id, m.product_name, s.order_date, m.price,
CASE
	WHEN mb.join_date <= s.order_date THEN 'Y'
	ELSE 'N'
	END as member_status
FROM menu m
JOIN sales s
ON s.product_id = m.product_id
LEFT JOIN members mb
ON mb.customer_id = s.customer_id
)
SELECT *,
CASE
	WHEN cte.member_status = 'Y' THEN RANK() OVER(PARTITION BY customer_id, member_status 
	ORDER BY order_date)
	ELSE NULL
	END AS ranking
FROM cte;