/*Business Scenario
You are an FP&A Analyst at NovaTech.
The CFO says:
"Revenue is growing, but I'm concerned that profitability may not be improving at the same rate."
Using FY2024-25 vs FY2023-24, analyze each product category.
Output Requirements
For every product category, show:
- Category
- FY2023-24 Revenue
- FY2024-25 Revenue
- Revenue YoY %
- FY2023-24 COGS
- FY2024-25 COGS
- COGS YoY %
- FY2023-24 Gross Profit
- FY2024-25 Gross Profit
- Gross Profit YoY %
- FY2023-24 Gross Margin %
- FY2024-25 Gross Margin %
- Gross Margin change in percentage points*/

with revenue_metric_2023 as(
select p.category, ROUND(SUM(od.quantity * od.unit_price * (1-od.discount_pct/100)),2) as revenue_2023, SUM(od.quantity * p.unit_cost) as COGS_2023
from products p
join order_details od
on p.product_id = od.product_id
join orders o
on o.order_id = od.order_id
where DATE(o.order_date) between '2023-04-01' and '2024-03-31'
group by p.category),
revenue_metric_2024 as(
select p.category, ROUND(SUM(od.quantity * od.unit_price * (1-od.discount_pct /100)),2) as revenue_2024, SUM(od.quantity * p.unit_cost) as COGS_2024
from products p
join order_details od
on p.product_id = od.product_id
join orders o
on o.order_id = od.order_id
where DATE(o.order_date) between '2024-04-01' and '2025-03-31'
group by p.category)
,
Revenue_yoy as(
 select r24.category, revenue_2023,revenue_2024, COGS_2023, COGS_2024, ROUND((revenue_2024 - revenue_2023)/ nullif(revenue_2023,0)*100,2) as revenue_yoy_pct
 from revenue_metric_2024 r24
 left join revenue_metric_2023 r23
 on r23.category = r24.category
 ),
 Gross_profit as(
 select category,revenue_2023,revenue_2024,COGS_2023, COGS_2024, revenue_2023 - COGS_2023 as Gross_profit_2023, revenue_2024 - COGS_2024 as Gross_profit_2024
 ,revenue_yoy_pct
 from revenue_yoy),
 gross_margin as(
 select category,revenue_2023,revenue_2024,COGS_2023, COGS_2024,Gross_profit_2023,Gross_profit_2024,
 ROUND(gross_profit_2023 / nullif(revenue_2023,0)*100,2) as gross_margin_2023,
 ROUND(gross_profit_2024 / nullif(revenue_2024,0)*100,2) as gross_margin_2024,revenue_yoy_pct
 from gross_profit)
 select category,revenue_2023,revenue_2024,COGS_2023, 
 COGS_2024,Gross_profit_2023,Gross_profit_2024,
 gross_margin_2023,gross_margin_2024,revenue_yoy_pct,
 ROUND((COGS_2024- COGS_2023)/nullif(COGS_2023,0)*100,2) as COGS_yoy_pp,
 ROUND((gross_profit_2024 - gross_profit_2023)/ nullif(gross_profit_2023,0)*100,2) as gross_profit_yoy, 
 gross_margin_2024 - gross_margin_2023 as gross_margin_changes_pp, 
 CASE WHEN revenue_yoy_pct > 0 and gross_margin_2024 - gross_margin_2023 < 0 THEN 'Margin Pressure' ELSE 'No Margin Pressure' 
 END as Status
 from gross_margin;


/*Q2 — Budget Overspend Investigation
Business Scenario
The CFO wants to understand which departments are creating the biggest cost-control problems in FY2024-25.
Analyze department + cost category.
Output
Show:
- Department
- Cost Category
- Budget
- Actual
- Variance
- Variance %
- Budget Utilization %
- Status*/

select * from departments;
select * from department_actuals;
select * from department_budget;

with department_metric as(
select da.department_id, da.cost_category, sum(budget_amount) as Budget, sum(actual_amount) as actual
from department_actuals da
join department_budget db
on da.cost_category = db.cost_category
and da.department_id = db.department_id
and da.month = db.month
where DATE(da.month) between '2024-04-01' and '2025-03-31'
group by da.department_id, da.cost_category),
variance_metric as(
select department_id,cost_category, actual , Budget, (actual - budget) as variance , ROUND((actual-budget)/nullif(budget,0)*100,2) as variance_pct,
ROUND((actual/nullif(budget,0)*100),2) as Budget_utilization_pct
from department_metric)
select department_id, cost_category, Actual,Budget,variance, variance_pct,budget_utilization_pct, 
CASE WHEN variance_pct > 10 THEN 'Significant Overspend'
WHEN variance_pct > 5 THEN 'Moderate Overspend'
WHEN Variance_pct >= 0 THEN 'Within Budget'
Else 'Underspend' END AS Status
from variance_metric;

/*Business Scenario
FP&A reviews whether the monthly revenue forecast is reliable.
For FY2024-25, compare actual sales against forecast_monthly.
Output
One row per:
Month + Channel + Product Category
Show:
- Month
- Channel
- Product Category
- Actual Revenue
- Forecast Revenue
- Variance
- Variance %
- Forecast Accuracy %
- Status*/
WITH revenue_metric AS (
    SELECT
        p.category,
        o.channel_id,
        DATE_FORMAT(o.order_date, '%Y-%m-01') AS month,
        SUM(
            od.quantity * od.unit_price *
            (1 - od.discount_pct / 100)
        ) AS actual_revenue
    FROM orders o
    JOIN order_details od
        ON o.order_id = od.order_id
    JOIN products p
        ON od.product_id = p.product_id
    WHERE o.order_date BETWEEN '2024-04-01' AND '2025-03-31'
    GROUP BY
        p.category,
        o.channel_id,
        DATE_FORMAT(o.order_date, '%Y-%m-01')
),

forecast_metric AS (
    SELECT
        fm.product_category,
        fm.channel_id,
        fm.forecast_month AS month,
        SUM(fm.forecast_revenue) AS forecast_revenue
    FROM forecast_monthly fm
    WHERE fm.forecast_month BETWEEN '2024-04-01' AND '2025-03-31'
    GROUP BY
        fm.product_category,
        fm.channel_id,
        fm.forecast_month
),

variance_metric AS (
    SELECT
        rm.category,
        rm.channel_id,
        rm.month,
        rm.actual_revenue,
        fm.forecast_revenue,
        rm.actual_revenue - fm.forecast_revenue AS variance,

        ROUND(
            (rm.actual_revenue - fm.forecast_revenue)
            / NULLIF(fm.forecast_revenue, 0) * 100,
            2
        ) AS variance_pct
    FROM revenue_metric rm
    JOIN forecast_metric fm
        ON rm.category = fm.product_category
       AND rm.channel_id = fm.channel_id
       AND rm.month = fm.month
),
dashboard_metric as(
SELECT
    category,
    c.channel_id,
    c.channel_name,
    month,
    actual_revenue,
    forecast_revenue,
    variance,
    variance_pct,
    ROUND(100-abs(actual_revenue - forecast_revenue) / nullif(forecast_revenue,0)*100,2) as forecast_accuracy_pct
FROM channels c
JOIN variance_metric vm
    ON c.channel_id = vm.channel_id)
select category,channel_id,channel_name, month,ROUND(actual_revenue,2) as actual_revenue,forecast_revenue,ROUND(variance,2) as variance,variance_pct,forecast_accuracy_pct,
CASE WHEN forecast_accuracy_pct > 95 THEN 'Excellent'
WHEN forecast_accuracy_pct >= 90 THEN 'Good'
WHEN forecast_accuracy_pct >= 80 then 'Need improvement'
ELSE 'Poor' end as status
from dashboard_metric;


/*Business Scenario
The CFO asks:
"How dependent are we on a small number of products?"

Using FY2024-25 revenue, calculate for each product:
- Product
- Category
- Revenue
- Revenue %
- Cumulative Revenue %
- Revenue Rank
Then classify products into:
- Top 20% Revenue Contributors
- Middle Contributors
- Long Tail
Interview requirement
Use a window-function-based approach.
Do not use a procedural loop.*/



/*Business Scenario
Management wants to understand whether FY2024-25 revenue growth came from existing customers or new customers.
Compare FY2023-24 and FY2024-25 customers.
For every customer who appears in either year, show:
- Customer ID
- Segment
- FY2023-24 Revenue
- FY2024-25 Revenue
- Revenue Change
- Revenue Change %
- Customer Status
Classify:
- New Customer
- Lost Customer
- Retained - Growing
- Retained - Declining
- Retained - Stable
Interview requirement
Customers with no revenue in one year must not disappear from the analysis.*/


/*Business Scenario
The supply-chain director says:
"Some of our best-selling products may be running with insufficient inventory."

Using FY2024-25:
For every product show:
- Product
- Category
- Revenue
- Units Sold
- Average Inventory
- Revenue Rank
- Inventory Rank
- Inventory-to-Units ratio
Identify products where:
- Revenue is above the overall product revenue average
- Average inventory is below the overall product inventory average
Classify them as:
High Sales / Low Inventory Risk
Interview requirement
Do not allow inventory snapshots to multiply sales transactions.*/


/*Business Scenario
The CFO wants to identify departments where costs are growing faster than business performance.
For FY2023-24 vs FY2024-25, calculate at department level:
- FY2023-24 Actual Cost
- FY2024-25 Actual Cost
- Cost YoY %
- FY2024-25 Budget
- FY2024-25 Actual
- Budget Variance
- Budget Variance %
- Cost as % of company revenue
- Cost Efficiency Status
Important
There is no direct department-to-product revenue relationship in the NovaTech schema.
You must recognize the appropriate analytical grain and avoid inventing one.*/


/*Business Scenario
You are presenting to the CFO.
The CFO says:
"Company revenue increased YoY, but gross profit declined. Find the products responsible."

For FY2023-24 vs FY2024-25, identify products where:
- Revenue increased
- Gross profit decreased
Show:
- Product
- Category
- FY2023-24 Revenue
- FY2024-25 Revenue
- Revenue YoY %
- FY2023-24 Gross Profit
- FY2024-25 Gross Profit
- Gross Profit YoY %
- FY2023-24 Gross Margin %
- FY2024-25 Gross Margin %
- Margin Change in percentage points
Then rank the products by gross-profit decline, worst first.
Interview expectation
Don't just produce the SQL.
Be prepared to explain:
"Why can revenue increase while gross profit decreases?"*/



/*Business Scenario
The CFO wants a shortlist of products that deserve immediate investigation.
A product should be flagged if all of these are true:
1. FY2024-25 revenue is above the average product revenue.
2. FY2024-25 gross margin is below the average product gross margin.
3. FY2024-25 revenue grew YoY.
4. FY2024-25 gross profit declined YoY.
Output
Show:
- Product
- Category
- Revenue
- Average Product Revenue
- Gross Margin
- Average Product Gross Margin
- Revenue YoY %
- Gross Profit YoY %
- Investigation Status
Interview requirement
Use window functions for the overall averages rather than creating unnecessary aggregate joins.*/


/*Business Scenario
You are in the final round for an FP&A Analyst position.
The CFO gives you this problem:
"NovaTech's overall profitability has weakened. I don't want a generic report. Tell me where I should investigate first and why."

Using FY2024-25 and FY2023-24 where required for comparison, build a management analysis that combines the validly related business dimensions available in the database.
Your analysis should cover, where the data supports it:
Revenue
- Revenue
- Units
- Revenue YoY %
Gross Profitability
- COGS
- Gross Profit
- Gross Margin %
- Gross Margin change
Operating Costs
- Actual
- Budget
- Variance
- Variance %
- Cost YoY %
Risk Indicators
Identify:
- High-revenue / low-margin products
- Revenue-growing / gross-profit-declining products
- Significant department overspending
- Departments with worsening cost trends
Final Requirement
Create a final classification such as:
- Immediate Investigation
- Monitor
- Healthy
But you must define the logic yourself based on the KPIs.
Critical Interview Constraint
You must not artificially join product-level profitability to department-level operating costs because the NovaTech schema does not provide a valid product → department mapping.
Instead, present the analysis at its valid grains and explain how the CFO can use both views together.*/
