--This verifies: expected_total_payment = total_paid + remaining_balance

DROP TABLE IF EXISTS reconciliation.loan_balance_check;

CREATE TABLE reconciliation.loan_balance_check AS
SELECT
    l.loan_id,
    l.loan_amount,
    l.expected_total_payment,
    COALESCE(SUM(r.amount_paid),0) AS total_paid,
    l.expected_total_payment - COALESCE(SUM(r.amount_paid),0) AS remaining_balance,

    CASE
        WHEN COALESCE(SUM(r.amount_paid),0) > l.expected_total_payment
        THEN 'Overpaid'

        WHEN COALESCE(SUM(r.amount_paid),0) = l.expected_total_payment
        THEN 'Closed'

        WHEN COALESCE(SUM(r.amount_paid),0) < l.expected_total_payment
        THEN 'Open'

        ELSE 'Error'
    END AS loan_status

FROM core.fact_loan l
LEFT JOIN core.fact_repayment r
ON l.loan_id = r.loan_id

GROUP BY
    l.loan_id,
    l.loan_amount,
    l.expected_total_payment;


--Detect loans that should have payments but none exist.

DROP TABLE IF EXISTS reconciliation.missing_payments;

CREATE TABLE reconciliation.missing_payments AS
SELECT
    l.loan_id,
    l.customer_id,
    l.loan_amount,
    l.disbursement_date
FROM core.fact_loan l
LEFT JOIN core.fact_repayment r
ON l.loan_id = r.loan_id
WHERE r.loan_id IS NULL;


--Identify loans with late payments.

DROP TABLE IF EXISTS reconciliation.delinquency_check;

CREATE TABLE reconciliation.delinquency_check AS
SELECT
    loan_id,
    MAX(days_past_due) AS max_days_past_due,
    COUNT(*) AS number_of_payments
FROM core.fact_repayment
GROUP BY loan_id;


--This checks whether branch totals match loan records.

DROP TABLE IF EXISTS reconciliation.branch_portfolio;

CREATE TABLE reconciliation.branch_portfolio AS
SELECT
    b.branch_id,
    b.region,
    COUNT(l.loan_id) AS total_loans,
    SUM(l.loan_amount) AS total_disbursed
FROM core.fact_loan l
JOIN core.dim_branch b
ON l.branch_id = b.branch_id
GROUP BY
    b.branch_id,
    b.region;




-- aging
DROP TABLE IF EXISTS reconciliation.portfolio_aging;

CREATE TABLE reconciliation.portfolio_aging AS
SELECT
    l.loan_id,
    l.branch_id,
    l.loan_amount,
    COALESCE(MAX(r.days_past_due),0) AS max_days_past_due,

    CASE
        WHEN COALESCE(MAX(r.days_past_due),0) = 0 THEN 'Current'
        WHEN COALESCE(MAX(r.days_past_due),0) BETWEEN 1 AND 7 THEN '1-7 days'
        WHEN COALESCE(MAX(r.days_past_due),0) BETWEEN 8 AND 30 THEN '8-30 days'
        WHEN COALESCE(MAX(r.days_past_due),0) BETWEEN 31 AND 90 THEN '31-90 days'
        ELSE '90+ days'
    END AS delinquency_bucket

FROM core.fact_loan l
LEFT JOIN core.fact_repayment r
ON l.loan_id = r.loan_id

GROUP BY
    l.loan_id,
    l.branch_id,
    l.loan_amount;



--risk
DROP TABLE IF EXISTS reconciliation.portfolio_risk_summary;

CREATE TABLE reconciliation.portfolio_risk_summary AS
SELECT
    delinquency_bucket,
    COUNT(*) AS number_of_loans,
    SUM(loan_amount) AS portfolio_amount
FROM reconciliation.portfolio_aging
GROUP BY delinquency_bucket;


--risk by region
DROP TABLE IF EXISTS reconciliation.portfolio_risk_by_region;

CREATE TABLE reconciliation.portfolio_risk_by_region AS
SELECT
    b.region,
    p.delinquency_bucket,
    SUM(p.loan_amount) AS portfolio_amount,
    COUNT(*) AS number_of_loans
FROM reconciliation.portfolio_aging p
JOIN core.dim_branch b
ON p.branch_id = b.branch_id
GROUP BY
    b.region,
    p.delinquency_bucket;




--snapshot
/*DROP TABLE IF EXISTS reconciliation.portfolio_risk_snapshot;

CREATE TABLE reconciliation.portfolio_risk_snapshot AS
SELECT
    CURRENT_DATE AS snapshot_date,
    b.region,
    p.delinquency_bucket,
    SUM(p.loan_amount) AS portfolio_amount,
    COUNT(*) AS number_of_loans
FROM reconciliation.portfolio_aging p
JOIN core.dim_branch b
ON p.branch_id = b.branch_id
GROUP BY
    b.region,
    p.delinquency_bucket;*/




--Step 1 — create the table once

CREATE TABLE IF NOT EXISTS reconciliation.portfolio_risk_snapshot (
    snapshot_date DATE,
    region TEXT,
    delinquency_bucket TEXT,
    portfolio_amount NUMERIC,
    number_of_loans INTEGER
);

--Step 2 — insert new snapshots each run

INSERT INTO reconciliation.portfolio_risk_snapshot
SELECT
    CURRENT_DATE AS snapshot_date,
    b.region,
    p.delinquency_bucket,
    SUM(p.loan_amount) AS portfolio_amount,
    COUNT(*) AS number_of_loans
FROM reconciliation.portfolio_aging p
JOIN core.dim_branch b
ON p.branch_id = b.branch_id
GROUP BY
    b.region,
    p.delinquency_bucket;


DROP TABLE IF EXISTS reconciliation.overpayment_check;

CREATE TABLE reconciliation.overpayment_check AS
SELECT
    loan_id,
    loan_amount,
    expected_total_payment,
    total_paid,
    total_paid - expected_total_payment AS overpayment_amount
FROM reconciliation.loan_balance_check
WHERE total_paid > expected_total_payment;


