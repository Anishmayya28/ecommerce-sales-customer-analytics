-- =========================================================
-- E-COMMERCE SALES & CUSTOMER ANALYTICS
-- Database: ecommerce_analytics
-- Tool: MySQL
-- Dataset: Olist Brazilian E-Commerce
-- =========================================================

USE ecommerce_analytics;


-- 1. OVERALL ORDER STATUS
-- Understand the distribution of order statuses.

SELECT
    order_status,
    COUNT(DISTINCT order_id) AS total_orders
FROM orders_clean
GROUP BY order_status
ORDER BY total_orders DESC;


-- 2. MONTHLY SALES PERFORMANCE
-- Track monthly orders, revenue and average order value.
-- Revenue includes product price and freight.

SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS sales_month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.freight_value), 2) AS freight_revenue,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_sales,
    ROUND(
        SUM(oi.price + oi.freight_value)
        / COUNT(DISTINCT o.order_id), 2
    ) AS average_order_value
FROM orders_clean AS o
JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
ORDER BY sales_month;


-- 3. TOP PRODUCT CATEGORIES BY REVENUE
-- Identify categories generating the highest product revenue.

SELECT
    COALESCE(
        ct.product_category_name_english,
        'unknown'
    ) AS product_category,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS item_lines,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(AVG(oi.price), 2) AS average_item_price
FROM orders_clean AS o
JOIN order_items AS oi
    ON o.order_id = oi.order_id
JOIN products AS p
    ON oi.product_id = p.product_id
LEFT JOIN category_translation AS ct
    ON p.product_category_name = ct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    COALESCE(ct.product_category_name_english, 'unknown')
ORDER BY product_revenue DESC
LIMIT 10;


-- 4. REVENUE BY PAYMENT METHOD
-- Compare payment methods by total payment value.

SELECT
    op.payment_type,
    COUNT(DISTINCT op.order_id) AS unique_orders,
    COUNT(*) AS payment_records,
    ROUND(SUM(op.payment_value), 2) AS total_payment_value,
    ROUND(AVG(op.payment_value), 2) AS average_payment_record
FROM order_payments AS op
JOIN orders_clean AS o
    ON op.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY op.payment_type
ORDER BY total_payment_value DESC;


-- 5. DELIVERY PERFORMANCE
-- Classify delivered orders as on time, delayed or missing a
-- delivery date.

SELECT
    CASE
        WHEN order_delivered_customer_date IS NULL
            THEN 'Delivery Date Missing'
        WHEN order_delivered_customer_date
             <= order_estimated_delivery_date
            THEN 'On Time or Early'
        ELSE 'Delayed'
    END AS delivery_status,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(
        100.0 * COUNT(DISTINCT order_id)
        / (SELECT COUNT(DISTINCT order_id)
           FROM orders_clean
           WHERE order_status = 'delivered'),
        2
    ) AS percentage_of_delivered_orders
FROM orders_clean
WHERE order_status = 'delivered'
GROUP BY delivery_status
ORDER BY total_orders DESC;


-- 6. CUSTOMER REVIEW SCORE DISTRIBUTION
-- Understand how customers rated their purchases.

SELECT
    review_score,
    COUNT(*) AS total_reviews,
    ROUND(
        100.0 * COUNT(*)
        / (SELECT COUNT(*) FROM order_reviews),
        2
    ) AS percentage_of_reviews
FROM order_reviews
WHERE review_score IS NOT NULL
GROUP BY review_score
ORDER BY review_score;


-- 7. REVIEW SCORE AND DELIVERY PERFORMANCE
-- Compare average review scores for on-time and delayed orders.
-- This is descriptive analysis, not proof of causation.

SELECT
    CASE
        WHEN o.order_delivered_customer_date IS NULL
            THEN 'Delivery Date Missing'
        WHEN o.order_delivered_customer_date
             <= o.order_estimated_delivery_date
            THEN 'On Time or Early'
        ELSE 'Delayed'
    END AS delivery_status,
    COUNT(DISTINCT o.order_id) AS reviewed_orders,
    ROUND(AVG(r.review_score), 2) AS average_review_score,
    ROUND(
        100.0 * SUM(
            CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END
        ) / COUNT(*),
        2
    ) AS low_rating_percentage
FROM orders_clean AS o
JOIN order_reviews AS r
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY delivery_status
ORDER BY average_review_score;


-- 8. DELIVERY DELAYS BY CUSTOMER STATE
-- Identify states with high delivery delay percentages.

SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    COUNT(DISTINCT CASE
        WHEN o.order_delivered_customer_date
             > o.order_estimated_delivery_date
        THEN o.order_id
    END) AS delayed_orders,
    ROUND(
        100.0 * COUNT(DISTINCT CASE
            WHEN o.order_delivered_customer_date
                 > o.order_estimated_delivery_date
            THEN o.order_id
        END) / COUNT(DISTINCT o.order_id),
        2
    ) AS delay_percentage
FROM orders_clean AS o
JOIN customers AS c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY delay_percentage DESC;
