
DROP TABLE IF EXISTS core.dim_branch;

CREATE TABLE core.dim_branch AS
SELECT
    branch_id,
    state,
    region
FROM raw.branches;



DROP TABLE IF EXISTS core.dim_agent;

CREATE TABLE core.dim_agent AS
SELECT
    agent_id,
    branch_id,
    hire_date,
    active_flag
FROM raw.agents;



DROP TABLE IF EXISTS core.dim_customer;

CREATE TABLE core.dim_customer AS
SELECT
    customer_id,
    gender,
    age,
    state,
    branch_id,
    registration_date,
    risk_segment
FROM raw.customers;


DROP TABLE IF EXISTS core.dim_date;

CREATE TABLE core.dim_date AS
SELECT
    d::date AS full_date,
    EXTRACT(WEEK FROM d) AS week,
    EXTRACT(MONTH FROM d) AS month,
    EXTRACT(YEAR FROM d) AS year
FROM generate_series(
    '2022-01-01'::date,
    '2026-12-31'::date,
    '1 day'
) d;


DROP TABLE IF EXISTS core.fact_loan;

CREATE TABLE core.fact_loan AS
SELECT
    loan_id,
    customer_id,
    agent_id,
    branch_id,
    disbursement_date,
    loan_amount,
    term_weeks,
    interest_rate,
    expected_total_payment
FROM raw.loans;


DROP TABLE IF EXISTS core.fact_repayment;

CREATE TABLE core.fact_repayment AS
SELECT
    repayment_id,
    loan_id,
    payment_date,
    amount_paid,
    days_past_due
FROM raw.repayments;