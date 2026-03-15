DROP TABLE IF EXISTS mart.loan_portfolio;

CREATE TABLE mart.loan_portfolio AS
SELECT
    l.loan_id,
    l.customer_id,
    l.agent_id,
    l.branch_id,
    b.region,
    l.disbursement_date,
    l.loan_amount,
    l.term_weeks,
    l.interest_rate,
    l.expected_total_payment,
    c.risk_segment,
    a.active_flag
FROM core.fact_loan l

LEFT JOIN core.dim_customer c
ON l.customer_id = c.customer_id

LEFT JOIN core.dim_branch b
ON l.branch_id = b.branch_id

LEFT JOIN core.dim_agent a
ON l.agent_id = a.agent_id;


DROP TABLE IF EXISTS mart.repayment_performance;

CREATE TABLE mart.repayment_performance AS
SELECT
    r.loan_id,
    SUM(r.amount_paid) AS total_paid,
    MAX(r.days_past_due) AS max_days_past_due
FROM core.fact_repayment r
GROUP BY r.loan_id;


DROP TABLE IF EXISTS mart.loan_status;

CREATE TABLE mart.loan_status AS
SELECT
    l.loan_id,
    l.loan_amount,
    COALESCE(p.total_paid,0) AS total_paid,
    l.expected_total_payment,
    (l.expected_total_payment - COALESCE(p.total_paid,0)) AS remaining_balance,
    p.max_days_past_due
FROM core.fact_loan l
LEFT JOIN mart.repayment_performance p
    ON l.loan_id = p.loan_id;


DROP TABLE IF EXISTS mart.repayment_summary;

CREATE TABLE mart.repayment_summary AS
SELECT
    r.payment_date,
    l.agent_id,
    l.branch_id,
    COUNT(r.repayment_id) AS number_of_payments,
    SUM(r.amount_paid) AS amount_paid,
    SUM(l.expected_total_payment / l.term_weeks) AS expected_payment
FROM core.fact_repayment r
JOIN core.fact_loan l
ON r.loan_id = l.loan_id
GROUP BY
    r.payment_date,
    l.agent_id,
    l.branch_id;

    DROP TABLE IF EXISTS mart.portfolio_aging;

CREATE TABLE mart.portfolio_aging AS
SELECT
    lp.loan_id,
    lp.customer_id,
    lp.branch_id,
    lp.agent_id,
    lp.region,
    lp.loan_amount,
    ls.remaining_balance,
    ls.max_days_past_due,

    CASE
        WHEN ls.max_days_past_due = 0 THEN 'Current'
        WHEN ls.max_days_past_due BETWEEN 1 AND 7 THEN '1-7'
        WHEN ls.max_days_past_due BETWEEN 8 AND 30 THEN '8-30'
        WHEN ls.max_days_past_due BETWEEN 31 AND 60 THEN '31-60'
        WHEN ls.max_days_past_due BETWEEN 61 AND 90 THEN '61-90'
        ELSE '90+'
    END AS delinquency_bucket,

    CASE
        WHEN ls.max_days_past_due > 30 THEN 1
        ELSE 0
    END AS par_flag,

    lp.active_flag

FROM mart.loan_portfolio lp
LEFT JOIN mart.loan_status ls
    ON lp.loan_id = ls.loan_id;