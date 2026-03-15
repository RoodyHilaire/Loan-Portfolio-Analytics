DROP TABLE IF EXISTS mart.portfolio_overview;

CREATE TABLE mart.portfolio_overview AS

SELECT
    l.loan_id,
    l.loan_amount,
    l.interest_rate,
    l.expected_total_payment,
    l.term_weeks,
    b.branch_id,
    b.region,
    

    COALESCE(r.total_paid,0) AS total_paid,

    l.expected_total_payment - COALESCE(r.total_paid,0) 
        AS outstanding_balance

FROM core.fact_loan l

LEFT JOIN (
    SELECT
        loan_id,
        SUM(amount_paid) AS total_paid
    FROM core.fact_repayment
    GROUP BY loan_id
) r
ON l.loan_id = r.loan_id

LEFT JOIN core.dim_branch b
ON l.branch_id = b.branch_id;


DROP TABLE IF EXISTS mart.mart_delinquency;
CREATE TABLE mart.mart_delinquency AS

WITH repayment_summary AS (
    SELECT
        loan_id,
        SUM(amount_paid) AS total_paid
    FROM core.fact_repayment
    GROUP BY loan_id
)

SELECT
    l.loan_id,
    l.branch_id,
    b.region,
    b.state,
    l.disbursement_date,
    l.term_weeks,
    l.expected_total_payment,
    l.interest_rate,

    COALESCE(r.total_paid,0) AS total_paid,

    (l.expected_total_payment - COALESCE(r.total_paid,0)) AS outstanding_balance,

    FLOOR((CURRENT_DATE - l.disbursement_date)/7) AS weeks_elapsed,

    (l.expected_total_payment / l.term_weeks) AS weekly_payment,

    (l.expected_total_payment / l.term_weeks) *
    FLOOR((CURRENT_DATE - l.disbursement_date)/7) AS expected_paid_to_date,

    (
        (l.expected_total_payment / l.term_weeks) *
        FLOOR((CURRENT_DATE - l.disbursement_date)/7)
        - COALESCE(r.total_paid,0)
    ) AS payment_gap,

    CASE
        WHEN (
            (l.expected_total_payment / l.term_weeks) *
            FLOOR((CURRENT_DATE - l.disbursement_date)/7)
            - COALESCE(r.total_paid,0)
        ) <= 0 THEN 'Current'

        WHEN (
            (
                (l.expected_total_payment / l.term_weeks) *
                FLOOR((CURRENT_DATE - l.disbursement_date)/7)
                - COALESCE(r.total_paid,0)
            ) / (l.expected_total_payment / l.term_weeks)
        ) * 7 <= 30 THEN '1-30 days'

        WHEN (
            (
                (l.expected_total_payment / l.term_weeks) *
                FLOOR((CURRENT_DATE - l.disbursement_date)/7)
                - COALESCE(r.total_paid,0)
            ) / (l.expected_total_payment / l.term_weeks)
        ) * 7 <= 60 THEN '31-60 days'

        WHEN (
            (
                (l.expected_total_payment / l.term_weeks) *
                FLOOR((CURRENT_DATE - l.disbursement_date)/7)
                - COALESCE(r.total_paid,0)
            ) / (l.expected_total_payment / l.term_weeks)
        ) * 7 <= 90 THEN '61-90 days'

        ELSE '90+ days'
    END AS delinquency_bucket

FROM core.fact_loan l

LEFT JOIN repayment_summary r
    ON l.loan_id = r.loan_id

LEFT JOIN core.dim_branch b
    ON l.branch_id = b.branch_id;




DROP TABLE IF EXISTS mart.executive_overview;

CREATE TABLE mart.executive_overview AS

WITH repayment_summary AS (
    SELECT
        loan_id,
        SUM(amount_paid) AS total_paid
    FROM core.fact_repayment
    GROUP BY loan_id
)

SELECT
    l.loan_id,
    l.branch_id,
    b.region,
    b.state,

    l.loan_amount,
    l.expected_total_payment,
    l.term_weeks,
    l.interest_rate,
    l.disbursement_date,

    COALESCE(r.total_paid,0) AS total_paid,

    (l.expected_total_payment - COALESCE(r.total_paid,0)) AS outstanding_balance,

    CASE
        WHEN (l.expected_total_payment - COALESCE(r.total_paid,0)) > 0
        THEN 1
        ELSE 0
    END AS active_loan_flag

FROM core.fact_loan l

LEFT JOIN repayment_summary r
    ON l.loan_id = r.loan_id

LEFT JOIN core.dim_branch b
    ON l.branch_id = b.branch_id;